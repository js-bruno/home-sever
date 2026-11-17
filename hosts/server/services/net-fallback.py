#!/usr/bin/env python3
"""Watchdog do link cabeado do shatterdome (enp3s0).

Não há segundo uplink (sem Wi-Fi, sem segunda placa). Este serviço mantém
a interface administrativamente up, garante o IP estático e a rota default
mesmo depois de uma queda/retorno do cabo, e testa internet de verdade
para registrar a indisponibilidade no journal.

Quando o cabo/roteador volta, a conectividade é restabelecida sem reboot.
Se o cabo ou o ISP continuar fora, não existe caminho alternativo para
onde trocar; o serviço apenas registra e continua tentando.
"""

import logging
import os
import re
import subprocess
import time

LOG = logging.getLogger("net-fallback")

WIRED_IFACE = os.environ.get("NET_FALLBACK_WIRED_IFACE", "enp3s0")
WIRED_ADDRESS = os.environ.get("NET_FALLBACK_WIRED_ADDRESS", "")
WIRED_GATEWAY = os.environ.get("NET_FALLBACK_WIRED_GATEWAY", "")
WIRED_METRIC = int(os.environ.get("NET_FALLBACK_WIRED_METRIC", "100"))

INTERVAL = max(5, int(os.environ.get("NET_FALLBACK_INTERVAL", "10")))
CHECK_TIMEOUT = max(1, int(os.environ.get("NET_FALLBACK_CHECK_TIMEOUT", "3")))
FAIL_LOG_EVERY = max(60, int(os.environ.get("NET_FALLBACK_FAIL_LOG_EVERY", "300")))

# Cloudflare por IP para o teste não depender de DNS; o gstatic devolve
# 204 como alternativa. Se qualquer um responder, existe saída real.
CHECK_URLS = (
    "https://1.1.1.1/cdn-cgi/trace",
    "https://www.gstatic.com/generate_204",
)

# Força mensagens do ip em inglês; o parsing não depende do locale.
ENV = {**os.environ, "LC_ALL": "C"}


def run(args, timeout=10):
    """Executa um comando e devolve CompletedProcess sem levantar erro."""
    try:
        return subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=ENV,
        )
    except subprocess.TimeoutExpired:
        LOG.warning("timeout ao executar: %s", " ".join(args))
        return subprocess.CompletedProcess(args, 124, stdout="", stderr="")
    except FileNotFoundError:
        LOG.error("comando não encontrado: %s", args[0])
        return subprocess.CompletedProcess(args, 127, stdout="", stderr="")


def carrier(iface):
    """True se a interface tem portadora física."""
    try:
        with open(f"/sys/class/net/{iface}/carrier", encoding="ascii") as handle:
            return handle.read().strip() == "1"
    except OSError:
        return False


def address_exists(iface, address):
    if not address:
        return True
    result = run(["ip", "-4", "-o", "addr", "show", "dev", iface])
    return address in result.stdout


def default_routes():
    """Lista as rotas default IPv4 atuais."""
    result = run(["ip", "-4", "route", "show", "default"])
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def route_matches(line, iface, metric):
    padded = f" {line} "
    return f" dev {iface} " in padded and f" metric {metric} " in padded


def delete_route(line, iface):
    """Remove uma rota default exata, preservando via/metric/proto."""
    args = ["ip", "-4", "route", "del", "default"]
    via = re.search(r"\bvia\s+(\S+)", line)
    if via:
        args += ["via", via.group(1)]
    args += ["dev", iface]
    metric = re.search(r"\bmetric\s+(\d+)", line)
    if metric:
        args += ["metric", metric.group(1)]
    proto = re.search(r"\bproto\s+(\S+)", line)
    if proto:
        args += ["proto", proto.group(1)]

    result = run(args)
    if result.returncode != 0:
        LOG.warning("falha ao remover rota '%s': %s", line, result.stderr.strip())
    return result.returncode == 0


def ensure_wired():
    """Restaura endereço e rota default do enp3s0 de forma idempotente.

    O networking scripted do NixOS só configura a interface no boot. Se o
    cabo cair e voltar, o kernel pode remover a rota default (e, em alguns
    casos, o endereço). Reaplicamos os dois sem depender de reboot.
    """
    if not os.path.exists(f"/sys/class/net/{WIRED_IFACE}"):
        return

    run(["ip", "link", "set", "dev", WIRED_IFACE, "up"], timeout=5)
    if not carrier(WIRED_IFACE):
        return

    if WIRED_ADDRESS and not address_exists(WIRED_IFACE, WIRED_ADDRESS):
        LOG.info("restaurando endereço %s em %s", WIRED_ADDRESS, WIRED_IFACE)
        result = run(["ip", "addr", "replace", WIRED_ADDRESS, "dev", WIRED_IFACE])
        if result.returncode != 0:
            LOG.warning(
                "não foi possível restaurar o endereço: %s", result.stderr.strip()
            )

    if not WIRED_GATEWAY:
        return

    desired = [
        line
        for line in default_routes()
        if route_matches(line, WIRED_IFACE, WIRED_METRIC)
        and f" via {WIRED_GATEWAY} " in f" {line} "
    ]
    if not desired:
        LOG.info(
            "restaurando rota default via %s em %s",
            WIRED_GATEWAY,
            WIRED_IFACE,
        )
        result = run(
            [
                "ip",
                "-4",
                "route",
                "replace",
                "default",
                "via",
                WIRED_GATEWAY,
                "dev",
                WIRED_IFACE,
                "proto",
                "static",
                "metric",
                str(WIRED_METRIC),
            ]
        )
        if result.returncode != 0:
            LOG.warning(
                "não foi possível restaurar a rota default: %s",
                result.stderr.strip(),
            )
            return

    # Normaliza rotas antigas via mesmo gateway com outra métrica (por
    # exemplo, metric 0 criada por uma geração anterior do network-setup).
    for line in default_routes():
        padded = f" {line} "
        if f" dev {WIRED_IFACE} " not in padded:
            continue
        if f" via {WIRED_GATEWAY} " not in padded:
            continue
        if route_matches(line, WIRED_IFACE, WIRED_METRIC):
            continue
        LOG.info("removendo rota default antiga do wired: %s", line)
        delete_route(line, WIRED_IFACE)


def has_internet(iface):
    """Testa saída real pela interface, sem depender do DNS do sistema."""
    if not iface or not carrier(iface):
        return False

    for url in CHECK_URLS:
        if "cdn-cgi/trace" in url:
            # Cloudflare por IP, sem DNS; confere o corpo para não aceitar
            # portal cativo que devolve 200 com HTML.
            result = run(
                [
                    "curl",
                    "-4",
                    "-fsS",
                    "--connect-timeout",
                    str(CHECK_TIMEOUT),
                    "--max-time",
                    str(CHECK_TIMEOUT + 1),
                    "--interface",
                    iface,
                    url,
                ],
                timeout=CHECK_TIMEOUT + 3,
            )
            if result.returncode == 0 and "h=1.1.1.1" in result.stdout:
                return True
        else:
            # Endpoint de connectivity-check: exige 204, não qualquer 200.
            result = run(
                [
                    "curl",
                    "-4",
                    "-sS",
                    "--connect-timeout",
                    str(CHECK_TIMEOUT),
                    "--max-time",
                    str(CHECK_TIMEOUT + 1),
                    "--interface",
                    iface,
                    "-o",
                    "/dev/null",
                    "-w",
                    "%{http_code}",
                    url,
                ],
                timeout=CHECK_TIMEOUT + 3,
            )
            if result.returncode == 0 and result.stdout.strip() == "204":
                return True

    return False


def describe_route():
    routes = default_routes()
    return "; ".join(routes) if routes else "nenhuma"


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    LOG.info(
        "watchdog do link cabeado iniciado (iface=%s endereço=%s gateway=%s)",
        WIRED_IFACE,
        WIRED_ADDRESS or "?",
        WIRED_GATEWAY or "?",
    )

    last_state = None
    last_status_log = 0.0
    last_failure_log = 0.0
    bad_checks = 0

    while True:
        started = time.monotonic()
        try:
            ensure_wired()

            up = carrier(WIRED_IFACE)
            ok = up and has_internet(WIRED_IFACE)

            if ok:
                bad_checks = 0
            else:
                bad_checks += 1

            now = time.monotonic()
            state = (up, ok)
            if state != last_state or now - last_status_log >= FAIL_LOG_EVERY:
                LOG.info(
                    "link=%s internet=%s falhas=%s | default=%s",
                    "up" if up else "down",
                    "ok" if ok else "falha",
                    bad_checks,
                    describe_route(),
                )
                last_state = state
                last_status_log = now

            if not ok and now - last_failure_log >= FAIL_LOG_EVERY:
                LOG.warning(
                    "sem internet pelo %s; não há segundo uplink configurado. "
                    "Confira cabo, porta do switch e roteador/ISP.",
                    WIRED_IFACE,
                )
                last_failure_log = now

        except Exception:  # noqa: BLE001 - o loop não pode morrer por um erro isolado
            LOG.exception("erro inesperado no ciclo do watchdog")

        elapsed = time.monotonic() - started
        time.sleep(max(2, INTERVAL - elapsed))


if __name__ == "__main__":
    raise SystemExit(main())
