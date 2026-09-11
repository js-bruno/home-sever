{...}:
{
  services.glance = {
    enable = true;
    openFirewall = true;

      settings = {
        server = {
          host = "0.0.0.0";
            port = 8082;
        };

        pages = [
        {
          name = "Homelab";
          columns = [
          {
            size = "full";
            widgets = [
            {
              type = "server-stats";
              servers = [
              {
                type = "local";
                name = "Shatterdome";
              }
              ];
            }
            {
              type = "monitor";
              title = "Serviços";
              cache = "1m";
              sites = [
              {
                title = "Netdata";
                url = "http://192.168.15.50:19999";
                icon = "si:netdata";
              }
              {
                title = "Paperless";
                url = "http://192.168.15.50:28981";
                icon = "si:paperlessngx";
              }
              ];
            }
            {
              type = "bookmarks";
              groups = [
              {
                title = "Acesso rápido";
                links = [
                {
                  title = "Minecraft (survival)";
                  url = "http://192.168.15.50:25565";
                }
                {
                  title = "SSH";
                  url = "ssh://gipsydanger@192.168.15.50:2222";
                }
                {
                  title = "Repositório nix-config";
                  url = "https://github.com/seuusuario/nix-config";
                }
                ];
              }
              ];
            }
            ];
          }
          {
            size = "small";
            widgets = [
            { type = "clock"; hourFormat = "24h"; }
            {
              type = "weather";
              location = "Fortaleza, Brazil";
              units = "metric";
            }
            {
              type = "rss";
              title = "NixOS";
              limit = 8;
              collapse-after = 5;
              feeds = [
              { url = "https://discourse.nixos.org/posts.rss"; }
              { url = "https://github.com/NixOS/nixpkgs/commits/master.atom"; }
              ];
            }
            ];
          }
          {
            size = "small";
            widgets = [
            {
              type = "hacker-news";
              limit = 10;
            }
            {
              type = "releases";
              cache = "1d";
              repositories = [
                "Infinidoge/nix-minecraft"
              ];
            }
            ];
          }
          ];
        }
        ];
      };
  };

}
