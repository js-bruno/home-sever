# hotel-vhost.nix — vhost público do hotel (via VPS, HTTPS/wss)
#
# O hotel é acessível publicamente em https://hotel.thisdev.space (nginx da
# VPS proxiando pelo túnel WireGuard). Quando o Host chega aqui é
# hotel.thisdev.space, o renderer-config.json precisa apontar para HTTPS e
# WSS — senão o browser bloqueia mixed content (http/ws dentro de página
# https). O vhost caravelho.com.br (módulo habbo-nixos) continua atendendo
# a LAN com ws/http.

{ config, pkgs, lib, ... }:
{
  services.nginx.virtualHosts."hotel.thisdev.space" = {
    root = "/var/www/habbo/public";

    locations."/client/" = {
      alias = "/home/gipsydanger/projects/habbo-dev/cms/public/client/";
      tryFiles = "$uri $uri/ /client/index.html";
    };

    # renderer-config.json com URLs https/wss quando o Host é o domínio público
    locations."= /client/renderer-config.json" = {
      extraConfig = ''
        sub_filter_once on;
        sub_filter 'ws://localhost:2096' 'wss://''${host}:2096';
        sub_filter 'http://localhost/client/c_images/' 'https://''${host}/client/c_images/';
        sub_filter 'http://localhost/client/dcr/hof_furni' 'https://''${host}/client/dcr/hof_furni';
        sub_filter 'http://localhost/client' 'https://''${host}/client';
        sub_filter_types application/json;
      '';
    };

    locations."/" = {
      index = "index.php index.html";
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };

    locations."~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.habbo.socket};
        fastcgi_index index.php;
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      '';
    };
  };
}