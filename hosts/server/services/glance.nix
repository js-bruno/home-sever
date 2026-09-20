{ config, pkgs, ... }:
{
  services.glance = {
    enable = true;

    settings = {
      server = {
        host = "0.0.0.0";
        port = 8082;
      };

      theme = {
        background-color = "240 8 9";
        primary-color = "43 50 70";
        contrast-multiplier = 1.1;
      };

      pages = [
        # ─── PÁGINA HOME ───
        {
          name = "Home";
          columns = [
            # Coluna esquerda (small)
            {
              size = "small";
              widgets = [
                { type = "calendar"; first-day-of-week = "monday"; }
                {
                  type = "rss";
                  title = "RSS Feed";
                  collapse-after = 4;
                  feeds = [
                    { url = "https://discourse.nixos.org/posts.rss"; title = "NixOS"; }
                  ];
                }
                {
                  type = "twitch-channels";
                  channels = [ "zackrawrr" "theprimeagen" "kevinpowellcss" "j_blow" ];
                }
              ];
            }

            # Coluna do meio (full)
            {
              size = "full";
              widgets = [
                {
                  type = "group";
                  widgets = [
                    { type = "hacker-news"; limit = 5; collapse-after = 5; }
                    { type = "lobsters"; limit = 5; collapse-after = 5; }
                  ];
                }
                {
                  type = "videos";
                  style = "horizontal-cards";
                  collapse-after = 4;
                  channels = [
                    # troque pelos IDs de canal que você acompanha
                    "UCXuqSBlHAE6Xw-yeJA0Tunw"  # Linus Tech Tips
                  ];
                }
                {
                  type = "group";
                  widgets = [
                    { type = "reddit"; subreddit = "technology"; show-thumbnails = true; collapse-after = 5; }
                    { type = "reddit"; subreddit = "science"; collapse-after = 5; }
                    { type = "reddit"; subreddit = "gaming"; collapse-after = 5; }
                  ];
                }
              ];
            }

            # Coluna direita (small)
            {
              size = "small";
              widgets = [
                {
                  type = "weather";
                  location = "Fortaleza, Brazil";
                  units = "metric";
                  hour-format = "24h";
                }
                {
                  type = "repository";
                  repository = "glanceapp/glance";
                  pull-requests-limit = 3;
                  issues-limit = 3;
                  commits-limit = -1;
                }
                {
                  type = "markets";
                  markets = [
                    { symbol = "BTC-USD"; name = "Bitcoin"; }
                    { symbol = "NVDA"; name = "NVIDIA"; }
                    { symbol = "AAPL"; name = "Apple"; }
                    { symbol = "GOOGL"; name = "Google"; }
                  ];
                }
              ];
            }
          ];
        }

        # ─── PÁGINA MARKETS ───
        {
          name = "Markets";
          columns = [
            {
              size = "full";
              widgets = [
                {
                  type = "markets";
                  sort-by = "change";
                  markets = [
                    { symbol = "SPY"; name = "S&P 500"; }
                    { symbol = "BTC-USD"; name = "Bitcoin"; }
                    { symbol = "NVDA"; name = "NVIDIA"; }
                    { symbol = "AAPL"; name = "Apple"; }
                    { symbol = "MSFT"; name = "Microsoft"; }
                    { symbol = "GOOGL"; name = "Google"; }
                  ];
                }
              ];
            }
          ];
        }

        # ─── PÁGINA GAMING ───
        {
          name = "Gaming";
          columns = [
            {
              size = "full";
              widgets = [
                { type = "reddit"; subreddit = "gaming"; collapse-after = 10; }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "twitch-top-games";
                  limit = 10;
                  collapse-after = 5;
                }
              ];
            }
          ];
        }

        # ─── PÁGINA HOMELAB (seus serviços) ───
        {
          name = "Homelab";
          columns = [
            {
              size = "full";
              widgets = [
                {
                  type = "server-stats";
                  servers = [ { type = "local"; name = "Shatterdome"; } ];
                }
                {
                  type = "monitor";
                  title = "Serviços";
                  cache = "1m";
                  sites = [
                    { title = "Netdata"; url = "http://meunetdata.com"; }
                    { title = "Paperless"; url = "http://meupaperless.com"; }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "bookmarks";
                  groups = [
                    {
                      title = "Acesso rápido";
                      links = [
                        { title = "Minecraft"; url = "http://192.168.15.50:25565"; }
                        { title = "SSH"; url = "ssh://gipsydanger@192.168.15.50:2222"; }
                      ];
                    }
                  ];
                }
                {
                  type = "releases";
                  cache = "1d";
                  repositories = [ "Infinidoge/nix-minecraft" ];
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
