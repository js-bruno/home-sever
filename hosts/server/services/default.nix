# services/default.nix — serviços deste host (shatterdome)
#
# O stack Habbo (emulador + CMS + nginx + mysql) vem do módulo externo
# habbo-nixos (ver flake.nix → nixosModules.habbo). Aqui ficam só os serviços
# específicos do host que não fazem parte do módulo.

{ config, lib, inputs, ... }:
{
  imports = [
    ./ssh.nix
    ./minecraft.nix
    ./paperless.nix
    ./glance.nix
    ./netdata.nix
    ./hotel-vhost.nix
    ./reverse-proxy.nix
    ./dnsmasq.nix
    ./excalidraw.nix
    ./service-metrics.nix
  ];

  # ── Stack Habbo DESLIGADO (temporário) ────────────────────────────────────
  # Religar: apagar estas 3 linhas (ou false→true) e rodar nixos-rebuild switch.
  systemd.services.habbo-arcturus.enable = false;  # emulador Java (maior RAM)
  systemd.services.mysql.enable          = false;  # MariaDB (só o habbo usa)
  systemd.services.phpfpm-habbo.enable   = false;  # pool PHP do CMS
}