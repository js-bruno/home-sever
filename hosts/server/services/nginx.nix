{...}: {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."caravelho.com.br" = {
      root = "/var/www/habbo/public";

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

       }
