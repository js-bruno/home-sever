{ config, pkgs, ... }:
let
  settings = pkgs.writeText "service-watch-settings.json" (builtins.toJSON {
    globally_open_tcp_ports = config.networking.firewall.allowedTCPPorts;
    # Matches the LAN-only ports documented in wireguard-vps.nix.
    lan_only_tcp_ports = [ 3306 8082 19999 28981 3000 3001 25565 2222 ];
    paperless_consumption_dir_is_public = config.services.paperless.consumptionDirIsPublic;
    ssh_password_authentication = config.services.openssh.settings.PasswordAuthentication;
    ssh_permit_root_login = config.services.openssh.settings.PermitRootLogin;
    minecraft_enabled = config.services.minecraft-servers.enable
      && config.services.minecraft-servers.servers.survival.enable;
    minecraft_online_mode = config.services.minecraft-servers.servers.survival.serverProperties."online-mode";
  });
in
{
  systemd.services.service-watch = {
    description = "Read-only health checks for shatterdome services";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 ${./service-watch.py}";
      Environment = "SERVICE_WATCH_SETTINGS=${settings}";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
    };
  };
}
