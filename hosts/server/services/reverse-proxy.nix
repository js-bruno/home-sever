# reverse-proxy.nix — proxy reverso LAN para os serviços HTTP do host
#
# Todos os serviços HTTP ganham um vhost próprio na porta 80, acessíveis só
# pela LAN (192.168.15.0/24) + localhost. As portas diretas (8081/8082/19999/
# 28981) foram fechadas no firewall — o único caminho de entrada é o nginx.
#
# Hosts (resolver no cliente apontando para 192.168.15.50):
#   docs.thisdev.space      → Quartz (localhost:8080)
#   glance.thisdev.space    → Glance dashboard (localhost:8082)
#   netdata.thisdev.space   → Netdata (localhost:19999)
#   paperless.thisdev.space → Paperless (localhost:28981)
#
# O hotel (caravelho.com.br / hotel.thisdev.space) já vive na porta 80 via
# módulo habbo-nixos + hotel-vhost.nix — intocados aqui. Portas TCP puras
# (minecraft 25565, ssh 2222, mysql 3306, ws Nitro 2096, game 3000) continuam
# diretas porque não são HTTP.

{ config, lib, ... }:
let
  lanOnly = ''
    allow 192.168.15.0/24;
    allow 127.0.0.1;
    deny all;
  '';
in
{
  services.nginx.virtualHosts = {
    "docs.thisdev.space" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = lanOnly;
      };
    };

    "glance.thisdev.space" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        extraConfig = lanOnly;
      };
    };

    "netdata.thisdev.space" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:19999";
        proxyWebsockets = true;
        extraConfig = lanOnly;
      };
    };

    "paperless.thisdev.space" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        extraConfig = lanOnly;
      };
    };
  };
}