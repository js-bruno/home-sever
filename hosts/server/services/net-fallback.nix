# net-fallback.nix — watchdog do link cabeado (enp3s0).
#
# O servidor não tem segundo uplink (sem Wi-Fi, sem segunda placa). Este
# serviço mantém o enp3s0 up, garante o IP estático e a rota default depois
# de uma queda/retorno do cabo, e testa internet de verdade para registrar
# a indisponibilidade no journal.
#
# Não há para onde "trocar" se o cabo/ISP continuar fora; o watchdog só
# restabelece a conectividade quando o link volta.
#
# Diagnóstico:
#
#   systemctl status net-fallback
#   journalctl -u net-fallback -f
#   ip route show default
#   ip -4 addr show dev enp3s0

{ config, pkgs, ... }:
let
  wiredIface = "enp3s0";

  wiredAddresses = config.networking.interfaces.${wiredIface}.ipv4.addresses;
  wiredAddress =
    if wiredAddresses == [ ] then
      ""
    else
      let
        first = builtins.head wiredAddresses;
      in
      "${first.address}/${toString first.prefixLength}";

  wiredGateway =
    if config.networking.defaultGateway == null then "" else config.networking.defaultGateway.address;

  wiredMetric =
    if config.networking.defaultGateway == null || config.networking.defaultGateway.metric == null then
      100
    else
      config.networking.defaultGateway.metric;
in
{
  systemd.services.net-fallback = {
    description = "Wired link watchdog (enp3s0 address/route/internet)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-addresses-enp3s0.service"
      "network-local-commands.service"
    ];

    path = with pkgs; [
      curl
      iproute2
      python3
    ];

    environment = {
      NET_FALLBACK_WIRED_IFACE = wiredIface;
      NET_FALLBACK_WIRED_ADDRESS = wiredAddress;
      NET_FALLBACK_WIRED_GATEWAY = wiredGateway;
      NET_FALLBACK_WIRED_METRIC = toString wiredMetric;
    };

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./net-fallback.py}";
      Restart = "always";
      RestartSec = 10;
      # Precisa de root para ip link/addr/route.
    };
  };
}
