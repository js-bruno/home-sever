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
                  channels = [ "theprimeagen" "yulla" "surskity11" ];
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
                    "UCEf5U1dB5a2e2S-XUlnhxSA"  # Diolinux
                    "UCYVrkMZdrjq5eICOG6Rxiwg"  # Tecnologia e Classe (TeClas)
                    "UCd3LVxg91E4vh4GqwKKfIKA"  # DioMagenta
                    "UCfJN9ob8XWpvfLiD_uif0Lw"  # Semydeus
                    "UC7aUVsRPKG4Ees4HHJvK8vw"  # Mistere
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
                    { title = "Hotel Habbo"; url = "http://caravelho.com.br"; }
                    { title = "Documentação (Quartz)"; url = "http://meudocs.com"; }
                    { title = "Glance"; url = "http://meuglance.com"; }
                    { title = "Paperless"; url = "http://meupaperless.com"; }
                    { title = "Excalidraw"; url = "http://meuexcalidraw.com"; }
                  ];
                }
                {
                  type = "custom-api";
                  title = "Métricas dos serviços";
                  cache = "1m";
                  url = "http://127.0.0.1:8090/metrics";
                  template = ''
                    <ul class="list list-gap-10">
                    {{ range .JSON.Array "services" }}
                      <li class="flex justify-between">
                        <span class="size-h4">{{ .String "name" }}</span>
                        <span class="size-h4 color-{{ if gt (.Float "cpu") 50 }}negative{{ else }}paragraph{{ end }}">
                          CPU {{ .Float "cpu" | printf "%.1f" }}% · RAM {{ .Float "rss_mb" | printf "%.0f" }}MB
                        </span>
                      </li>
                    {{ end }}
                    </ul>
                  '';
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
                        { title = "Hotel Habbo"; url = "http://caravelho.com.br"; }
                        { title = "Documentação"; url = "http://meudocs.com"; }
                        { title = "Dashboards (Glance)"; url = "http://meuglance.com"; }
                        { title = "Documentos (Paperless)"; url = "http://meupaperless.com"; }
                        { title = "Desenhos (Excalidraw)"; url = "http://meuexcalidraw.com"; }
                        { title = "Minecraft"; url = "http://192.168.15.50:25565"; }
                        { title = "SSH"; url = "ssh://***@192.168.15.50:2222"; }
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
