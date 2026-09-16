# habbo.nix — Habbo Retro (Arcturus Morningstar 3.5.5)
#
# Emulador: Arcturus Morningstar 3.5.5 (Java 17)
#   - Game server : 0.0.0.0:2096 (já liberado no firewall: hosts/server/network-local.nix)
#   - RCON        : 127.0.0.1:3560 (loopback)
#   - Config      : habbo-dev/arcturus/config.ini (lê o DB 'habbo')
#   - Depende do  : services/mysql.nix (MariaDB + usuário 'habbo')
#
# CMS: Atom CMS (Laravel) é servido pelo nginx.nix + pool phpfpm 'habbo'
#   (definido no configuration.nix). Este módulo só cuida do emulador.

{ pkgs, ... }:

let
  arcturusJar = "/home/gipsydanger/projects/habbo-dev/arcturus/Habbo-3.5.5-jar-with-dependencies.jar";
  arcturusDir = "/home/gipsydanger/projects/habbo-dev/arcturus";
in
{
  systemd.services.habbo-arcturus = {
    description = "Habbo Retro - Arcturus Morningstar 3.5.5 Emulator";
    after = [ "mysql.service" "network.target" ];
    wants = [ "mysql.service" ];

    serviceConfig = {
      Type = "simple";
      User = "gipsydanger";
      WorkingDirectory = arcturusDir;
      ExecStart = "${pkgs.jdk17}/bin/java -jar ${arcturusJar}";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 60;
    };

    wantedBy = [ "multi-user.target" ];
  };
}