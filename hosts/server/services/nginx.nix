{ config, pkgs, lib, ... }: {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."caravelho.com.br" = {
      root = "/var/www/habbo/public";

      # O nitro-react lê /client/renderer-config.json e conecta em socket.url.
      # O valor é fixo (ws://localhost) no arquivo estático; injetamos o host
      # real via sub_filter para funcionar por localhost / IP / domínio.
      locations."= /client/renderer-config.json" = {
        extraConfig = ''
          sub_filter_once on;
          sub_filter 'ws://localhost:2096' 'ws://''${host}:2096';
          sub_filter 'http://localhost/client/c_images/' 'http://''${host}/client/c_images/';
          sub_filter 'http://localhost/client/dcr/hof_furni' 'http://''${host}/client/dcr/hof_furni';
          sub_filter 'http://localhost/client' 'http://''${host}/client';
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
  };

  # O CMS vive em ~/projects/habbo-dev → /var/www/habbo (symlink).
  # O systemd do NixOS aplica ProtectHome=true no nginx por padrão, o que
  # bloqueia a leitura de /home mesmo com permissões corretas. Desativamos
  # para o vhost do habbo conseguir servir o public do Laravel.
  systemd.services.nginx.serviceConfig.ProtectHome = lib.mkForce false;
}