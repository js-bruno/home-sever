# docs-vhost.nix — vhost LAN para a documentação Quartz (http://docs.thisdev.space)
#
# A documentação de desenvolvimento (Quartz) roda em localhost:8080 e precisa
# ser acessível pela LAN 192.168.15.0/24. O nginx faz proxy reverso apenas
# para a rede local (allow LAN, deny all) — não sai pela VPS.

{ config, pkgs, lib, ... }:
{
  services.nginx.virtualHosts."docs.thisdev.space" = {
    listen = [
      { addr = "0.0.0.0"; port = 8081; }
    ];

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        allow 192.168.15.0/24;
        allow 127.0.0.1;
        deny all;
      '';
    };
  };
}