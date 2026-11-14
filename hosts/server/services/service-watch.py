#!/usr/bin/env python3
"""Read-only health checks and configuration audit for the NixOS host."""

import json
import os
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

INTERVAL = 60
PORT = 8091
HEALTH_BIND = "127.0.0.1"
DISK_LIMIT = 90
MEMORY_MIN_MB = 256
SERVICES = {
    "Habbo emulator": "habbo-arcturus.service",
    "MySQL": "mysql.service",
    "Nginx": "nginx.service",
    "Paperless web": "paperless-web.service",
    "Paperless queue": "paperless-task-queue.service",
    "Paperless scheduler": "paperless-scheduler.service",
    "Paperless consumer": "paperless-consumer.service",
    "Paperless Redis": "redis-paperless.service",
    "DNS (dnsmasq)": "dnsmasq.service",
    "WireGuard": "wireguard-wg0.service",
    "Glance": "glance.service",
    "Netdata": "netdata.service",
    "Excalidraw": "podman-excalidraw.service",
    "SSH": "sshd.service",
    "Service metrics": "service-metrics.service",
}
HTTP_TARGETS = {
    "Habbo (LAN)": ("http://127.0.0.1/", "caravelho.com.br"),
    "Glance": ("http://127.0.0.1:8082/", None),
    "Paperless": ("http://127.0.0.1:28981/", None),
    "Netdata": ("http://127.0.0.1:19999/api/v1/info", None),
    "Excalidraw": ("http://127.0.0.1:5000/", None),
    "Service metrics": ("http://127.0.0.1:8090/metrics", None),
}


def resource_check(name, value, limit, below):
    failed = value < limit if below else value >= limit
    unit = "MB" if "memória" in name.lower() or name == "memory" else "%"
    return {
        "name": name,
        "status": "fail" if failed else "ok",
        "value": round(value, 1),
        "limit": limit,
        "unit": unit,
        "message": f"{name}: {value:.1f}{unit} (threshold {limit}{unit})",
    }


def next_cycle_deadline(cycle_started):
    return cycle_started + INTERVAL


def http_status_check(name, code):
    return {
        "name": name,
        "status": "ok" if 200 <= code < 400 else "fail",
        "value": code,
        "message": f"{name}: HTTP {code}",
    }


def check_unit(name, unit):
    try:
        result = subprocess.run(
            ["systemctl", "is-active", unit],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        active = result.returncode == 0 and result.stdout.strip() == "active"
        state = result.stdout.strip() or result.stderr.strip() or "unknown"
    except (OSError, subprocess.TimeoutExpired) as exc:
        active = False
        state = str(exc)
    return {
        "name": name,
        "status": "ok" if active else "fail",
        "value": state,
        "message": f"{name}: {state}",
    }


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


HTTP_OPENER = urllib.request.build_opener(NoRedirect)


def check_http(name, url, host=None):
    headers = {"User-Agent": "shatterdome-service-watch/1"}
    if host:
        headers["Host"] = host
    request = urllib.request.Request(url, headers=headers)
    try:
        with HTTP_OPENER.open(request, timeout=5) as response:
            return http_status_check(name, response.status)
    except urllib.error.HTTPError as exc:
        return http_status_check(name, exc.code)
    except (OSError, TimeoutError) as exc:
        return {"name": name, "status": "fail", "value": str(exc), "message": f"{name}: indisponível ({exc})"}


def check_resources():
    disk = shutil.disk_usage("/")
    disk_percent = disk.used / disk.total * 100 if disk.total else 0
    mem_total = mem_available = 0
    with open("/proc/meminfo", encoding="ascii") as meminfo:
        for line in meminfo:
            key, value, *_ = line.split()
            if key == "MemTotal:":
                mem_total = int(value) // 1024
            elif key == "MemAvailable:":
                mem_available = int(value) // 1024
    return [
        resource_check("Disco /", disk_percent, DISK_LIMIT, below=False),
        resource_check("Memória disponível", mem_available, MEMORY_MIN_MB, below=True),
        {
            "name": "Memória RAM",
            "status": "ok",
            "value": mem_total,
            "unit": "MB",
            "message": f"Memória RAM: {mem_total}MB total; {mem_available}MB disponível",
        },
    ]


def audit_configuration(settings):
    findings = []
    if settings.get("ssh_password_authentication", False):
        findings.append({
            "code": "ssh-password-authentication",
            "name": "SSH: autenticação por senha habilitada",
            "status": "warn",
            "value": "PasswordAuthentication=yes",
            "message": "SSH aceita autenticação por senha; prefira chaves públicas",
        })
    if settings.get("ssh_permit_root_login") in (True, "yes", "without-password", "prohibit-password"):
        findings.append({
            "code": "ssh-root-login",
            "name": "SSH: login root permitido",
            "status": "warn",
            "value": str(settings["ssh_permit_root_login"]),
            "message": "SSH permite login direto como root",
        })

    exposed = sorted(
        set(settings.get("globally_open_tcp_ports", []))
        & set(settings.get("lan_only_tcp_ports", []))
    )
    if exposed:
        findings.append({
            "code": "firewall-lan-only-ports",
            "name": "Portas LAN abertas globalmente",
            "status": "warn",
            "value": ", ".join(map(str, exposed)),
            "message": f"Portas previstas como LAN-only estão abertas globalmente: {exposed}",
        })
    if settings.get("paperless_consumption_dir_is_public"):
        findings.append({
            "code": "paperless-public-consumption",
            "name": "Paperless: diretório de consumo público",
            "status": "warn",
            "value": "habilitado",
            "message": "Paperless permite que todos os usuários escrevam no diretório de consumo",
        })
    if settings.get("minecraft_enabled") and not settings.get("minecraft_online_mode", True):
        findings.append({
            "code": "minecraft-offline-mode",
            "name": "Minecraft: autenticação offline",
            "status": "warn",
            "value": "online-mode=false",
            "message": "Minecraft está ativo sem autenticação oficial (online-mode=false)",
        })
    return findings


def load_audit_configuration(path):
    with open(path, encoding="utf-8") as config_file:
        return json.load(config_file)


def collect(audit_settings):
    checks = [check_unit(name, unit) for name, unit in SERVICES.items()]
    checks.extend(check_http(name, url, host) for name, (url, host) in HTTP_TARGETS.items())
    checks.extend(check_resources())
    audit = audit_configuration(audit_settings)
    failed = sum(check["status"] == "fail" for check in checks)
    warnings = len(audit)
    status = "fail" if failed else "warn" if warnings else "ok"
    return {
        "updated": datetime.now(timezone.utc).isoformat(),
        "status": status,
        "summary": f"{failed} falha(s), {warnings} aviso(s) de auditoria em {len(checks)} verificações",
        "checks": checks,
        "audit": audit,
    }


class State:
    payload = {"status": "starting", "summary": "Primeira coleta em andamento", "checks": []}
    last_failures: tuple[str, ...] | None = None


def publish(payload):
    alerts = [check["message"] for check in payload["checks"] if check["status"] == "fail"]
    alerts.extend(item["message"] for item in payload.get("audit", []))
    current = tuple(sorted(alerts))
    if State.last_failures is None:
        message = "Vigia de serviços: " + ("; ".join(current) if current else "verificação inicial sem alertas")
        print(message, flush=True)
    elif current != State.last_failures:
        message = "Vigia de serviços: " + ("; ".join(current) if current else "todos os alertas resolvidos")
        print(message, flush=True)
    State.last_failures = current
    State.payload = payload


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0] != "/health":
            self.send_error(404)
            return
        body = json.dumps(State.payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


def poll_once(audit_settings):
    cycle_started = time.monotonic()
    publish(collect(audit_settings))
    return max(0, next_cycle_deadline(cycle_started) - time.monotonic())


def poll_forever(audit_settings):
    while True:
        time.sleep(poll_once(audit_settings))


def serve():
    audit_settings = load_audit_configuration(os.environ["SERVICE_WATCH_SETTINGS"])
    # Keep the latest snapshot available while checks run in the background.
    threading.Thread(target=poll_forever, args=(audit_settings,), daemon=True).start()
    # The endpoint is loopback-only; Glance fetches it locally.
    ThreadingHTTPServer((HEALTH_BIND, PORT), Handler).serve_forever()


if __name__ == "__main__":
    serve()
