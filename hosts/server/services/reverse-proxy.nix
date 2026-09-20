# reverse-proxy.nix — proxy reverso LAN para os serviços HTTP do host
#
# Hosts locais (resolvidos pelo dnsmasq do próprio servidor, ver dnsmasq.nix):
#   meudocs.com        → Quartz (localhost:8080)
#   meuglance.com      → Glance dashboard (localhost:8082)
#   meunetdata.com     → Netdata (localhost:19999)
#   meupaperless.com   → Paperless (localhost:28981)
#
# Todos restritos à LAN (192.168.15.0/24) + localhost. Os nomes *.thisdev.space
# ficam só para o acesso público via VPS. O hotel (caravelho.com.br /
# hotel.thisdev.space) já vive na porta 80 via módulo habbo-nixos +
# hotel-vhost.nix — intocados aqui. Portas TCP puras (minecraft 25565, ssh
# 2222, mysql 3306, ws Nitro 2096, game 3000) continuam diretas.

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
    "meudocs.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = lanOnly;
      };
    };

    "meuglance.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
        extraConfig = lanOnly;
      };
    };

    "meunetdata.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:19999";
        proxyWebsockets = true;
        extraConfig = lanOnly;
      };
    };

    "meupaperless.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        extraConfig = lanOnly;
      };
    };
  };
}