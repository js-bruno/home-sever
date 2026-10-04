# service-metrics.nix — métricas por serviço (sem depender do Netdata)
#
# Expõe um endpoint HTTP local (127.0.0.1:8090/metrics) com uso de CPU %
# e RAM (RSS em MB) por serviço, lendo /proc diretamente. O Glance consome
# via widget custom-api na tab Homelab.
#
# Serviços monitorados (matched por usuário/processo):
#   habbo      -> processos do usuário 'habbo' (emulador Java)
#   mysql      -> processos do usuário 'mysql'
#   nginx      -> processos do usuário 'nginx' (master + workers + php-fpm pool habbo)
#   paperless  -> processos do usuário 'paperless' (web + celery + consumer)
#   glance     -> processo 'glance' (DynamicUser, UID fora do passwd → match por comm)
#   excalidraw -> 'nginx -g daemon off' root (container podman)
#
# CPU% é calculado como delta de jiffies entre duas coletas (intervalo de 1s)
# sobre o total de jiffies do sistema no mesmo intervalo — por isso a primeira
# requisição retorna 0% (precisa de 2 amostras).
#
# Sem bind externo: só 127.0.0.1, não exposta no reverse-proxy.

{ config, pkgs, ... }:

let
  port = 8090;
  py = pkgs.python3;
in
{
  systemd.services.service-metrics = {
    description = "Service metrics aggregator for Glance";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${py}/bin/python3 ${pkgs.writeText "svc-metrics.py" ''
import json
import os
import pwd
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PAGE = os.sysconf("SC_PAGE_SIZE")
PORT = ${toString port}

# serviço -> regras de match: user (nome) ou cmd+arg
# uid é necessário p/ serviços com DynamicUser (glance) que não aparecem em /etc/passwd
SERVICES = [
    ("habbo",     {"user": "habbo"}),
    ("mysql",     {"user": "mysql"}),
    ("nginx",     {"user": "nginx"}),
    ("paperless", {"user": "paperless"}),
    ("glance",    {"user": "glance", "cmd": "glance"}),
    ("excalidraw", {"cmd": "nginx", "arg": "daemon off"}),
]

UID2NAME = {u.pw_uid: u.pw_name for u in pwd.getpwall()}


def read_total_jiffies():
    with open("/proc/stat") as f:
        parts = f.readline().split()
    return sum(int(x) for x in parts[1:8])


def snapshot():
    """Lê /proc e retorna {service: {"cpu_jiffies": int, "rss_mb": float}}."""
    agg = {name: {"cpu_jiffies": 0, "rss_mb": 0.0} for name, _ in SERVICES}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open("/proc/%s/stat" % pid) as f:
                stat_text = f.read()
            left = stat_text.index("(") + 1
            right = stat_text.rfind(")")
            comm = stat_text[left:right]
            rest = stat_text[right + 2:].split()
            utime = int(rest[11])
            stime = int(rest[12])
            rss_pages = int(rest[21])
            with open("/proc/%s/cmdline" % pid, "rb") as f:
                cmdline = f.read().replace(b"\0", b" ").decode(errors="replace").strip()
            uid = os.stat("/proc/%s" % pid).st_uid
        except (OSError, ValueError, IndexError):
            continue

        uname = UID2NAME.get(uid)
        for name, rule in SERVICES:
            # 1) match por usuário (resolve o nome do UID)
            if rule.get("user") and uname == rule["user"]:
                agg[name]["cpu_jiffies"] += utime + stime
                agg[name]["rss_mb"] += rss_pages * PAGE / (1024 * 1024)
                break
            # 2) match por comm (DynamicUser sem entrada em /etc/passwd: uid None)
            if rule.get("cmd") and comm == rule["cmd"] and uname is None:
                if rule.get("arg"):
                    if rule["arg"] in cmdline:
                        agg[name]["cpu_jiffies"] += utime + stime
                        agg[name]["rss_mb"] += rss_pages * PAGE / (1024 * 1024)
                    break
                else:
                    agg[name]["cpu_jiffies"] += utime + stime
                    agg[name]["rss_mb"] += rss_pages * PAGE / (1024 * 1024)
                    break
            # 3) match por comm+arg para processos root (excalidraw container)
            if rule.get("cmd") and comm == rule["cmd"] and not rule.get("user"):
                if rule.get("arg") and rule["arg"] in cmdline:
                    agg[name]["cpu_jiffies"] += utime + stime
                    agg[name]["rss_mb"] += rss_pages * PAGE / (1024 * 1024)
                break
    return agg


class State:
    prev_agg = None
    prev_total = None
    prev_time = None


def build_payload():
    now = time.monotonic()
    agg = snapshot()
    total = read_total_jiffies()

    out = []
    if State.prev_agg is None:
        # primeira coleta: sem delta, retorna só RSS
        for name, _ in SERVICES:
            a = agg[name]
            if a["rss_mb"] > 0 or a["cpu_jiffies"] > 0:
                out.append({"name": name, "cpu": 0.0, "rss_mb": round(a["rss_mb"], 1)})
    else:
        dt = now - State.prev_time
        d_total = total - State.prev_total
        if dt > 0 and d_total > 0:
            for name, _ in SERVICES:
                a = agg[name]
                p = State.prev_agg[name]
                d_cpu = a["cpu_jiffies"] - p["cpu_jiffies"]
                cpu_pct = max(0.0, d_cpu / d_total * 100.0) if d_cpu > 0 else 0.0
                if a["rss_mb"] > 0 or cpu_pct > 0:
                    out.append({"name": name,
                                "cpu": round(cpu_pct, 1),
                                "rss_mb": round(a["rss_mb"], 1)})

    State.prev_agg = agg
    State.prev_total = total
    State.prev_time = now
    return {"updated": int(time.time()), "services": out}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?")[0] != "/metrics":
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(build_payload()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    server.serve_forever()
      ''}";
      Restart = "on-failure";
      RestartSec = 3;
      DynamicUser = true;
    };
  };
}