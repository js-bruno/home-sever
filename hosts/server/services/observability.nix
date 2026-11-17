# observability.nix — Prometheus + Loki + Grafana + node_exporter/Alloy
#
# - Prometheus: 127.0.0.1:9090, retenção curta (7d / 2 GB).
# - node_exporter: 127.0.0.1:9100 (coletor systemd habilitado).
# - Loki: 127.0.0.1:3100, retenção de 7 dias em /var/lib/loki.
# - Alloy: lê o journal de Forgejo/comin/runner/nginx/Grafana/Prometheus e
#   envia para o Loki; UI/API local em 127.0.0.1:12345.
# - Grafana: 0.0.0.0:3002, mas o firewall só libera 192.168.15.0/24.
# - Scrapes: node_exporter, Forgejo (/metrics) e comin (exporter 4243).
#
# A senha inicial do admin é gerada no primeiro start em
# /var/lib/grafana/admin-password (root:grafana, 0400). Leia com:
#   sudo cat /var/lib/grafana/admin-password
# O arquivo não entra no Nix store. Se o perder, use:
#   sudo -u grafana grafana cli admin reset-admin-password NOVA_SENHA
#
# Acesso LAN: http://192.168.15.50:3002
# O Grafana NÃO é exposto globalmente: a 3002 é liberada só na interface da
# LAN (enp3s0) no fim deste arquivo. Não usamos extraInputRules porque o
# firewall roda no backend iptables, que ignora essa opção (nftables-only).

{ config, lib, pkgs, ... }:
let
  dataDir = config.services.grafana.dataDir;

  dashboards = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "shatterdome.json";
      path = ./grafana-dashboard.json;
    }
  ];
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "7d";
    extraFlags = [ "--storage.tsdb.retention.size=2GB" ];

    scrapeConfigs = [
      {
        job_name = "prometheus";
        scrape_interval = "30s";
        static_configs = [ { targets = [ "127.0.0.1:9090" ]; } ];
      }
      {
        job_name = "node";
        scrape_interval = "30s";
        static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
      }
      {
        job_name = "forgejo";
        scrape_interval = "30s";
        metrics_path = "/metrics";
        static_configs = [ { targets = [ "127.0.0.1:3001" ]; } ];
      }
      {
        job_name = "comin";
        scrape_interval = "30s";
        metrics_path = "/metrics";
        static_configs = [ { targets = [ "127.0.0.1:4243" ]; } ];
      }
    ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  # Loki single-binary: logs ficam em /var/lib/loki, retenção curta.
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
        grpc_listen_address = "127.0.0.1";
        grpc_listen_port = 9096;
        log_level = "warn";
      };

      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
      };

      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };
        filesystem.directory = "/var/lib/loki/chunks";
      };

      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
        compaction_interval = "10m";
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
      };

      limits_config = {
        retention_period = "168h";
        allow_structured_metadata = true;
        volume_enabled = true;
      };

      analytics.reporting_enabled = false;
    };
  };

  systemd.services.loki.serviceConfig = {
    MemoryHigh = "256M";
    MemoryMax = "512M";
  };

  # Alloy lê o journal só dos serviços relevantes e empurra para o Loki.
  services.alloy = {
    enable = true;
    extraFlags = [
      "--server.http.listen-addr=127.0.0.1:12345"
      "--disable-reporting"
    ];
  };

  environment.etc."alloy/config.alloy".text = ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal__hostname"]
        target_label  = "hostname"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "forgejo" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=forgejo.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.source.journal "comin" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=comin.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.source.journal "runner" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=gitea-runner-local.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.source.journal "nginx" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=nginx.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.source.journal "grafana" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=grafana.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.source.journal "prometheus" {
      forward_to    = [loki.write.local.receiver]
      matches       = "_SYSTEMD_UNIT=prometheus.service"
      max_age       = "12h"
      relabel_rules = loki.relabel.journal.rules
      labels        = { host = "shatterdome" }
    }

    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
      }
    }
  '';

  systemd.services.alloy.serviceConfig = {
    # O módulo já adiciona systemd-journal; adm é exigido pelo journal reader.
    SupplementaryGroups = lib.mkForce [ "systemd-journal" "adm" ];
    MemoryHigh = "128M";
    MemoryMax = "256M";
  };

  # Protege o host (2c/2t, 7.6 GiB) contra picos dos novos serviços.
  systemd.services.prometheus.serviceConfig = {
    MemoryHigh = "384M";
    MemoryMax = "768M";
  };
  systemd.services.prometheus-node-exporter.serviceConfig.MemoryMax = "64M";

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3002;
        domain = "192.168.15.50";
        root_url = "http://192.168.15.50:3002/";
        serve_from_sub_path = false;
      };

      security = {
        admin_user = "admin";
        # File provider: os valores reais ficam fora do Nix store.
        admin_password = "$__file{${dataDir}/admin-password}";
        secret_key = "$__file{${dataDir}/secret-key}";
        disable_gravatar = true;
      };

      users.allow_sign_up = false;
      "auth.anonymous".enabled = false;
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };
      log.level = "warn";
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          uid = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
          jsonData.timeInterval = "30s";
        }
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          access = "proxy";
          url = "http://127.0.0.1:3100";
          editable = false;
        }
      ];

      dashboards.settings.providers = [
        {
          name = "shatterdome";
          options.path = dashboards;
          disableDeletion = true;
          updateIntervalSeconds = 30;
        }
      ];
    };
  };

  # O Grafana roda como usuário grafana; o preStart também. Gera a senha
  # inicial uma única vez, sem colocar segredo no store.
  systemd.services.grafana.preStart = lib.mkAfter ''
    if [ ! -s ${dataDir}/admin-password ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 24 | ${pkgs.coreutils}/bin/tr -d '\n' > ${dataDir}/admin-password
      chmod 0400 ${dataDir}/admin-password
    fi
    if [ ! -s ${dataDir}/secret-key ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 32 | ${pkgs.coreutils}/bin/tr -d '\n' > ${dataDir}/secret-key
      chmod 0400 ${dataDir}/secret-key
    fi
  '';

  systemd.services.grafana.serviceConfig = {
    MemoryHigh = "320M";
    MemoryMax = "512M";
  };

  # Única alteração de rede: 3002 aceito na NIC da LAN, nada global.
  # Gera `-i enp3s0 --dport 3002 ACCEPT` no backend iptables atual.
  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [ 3002 ];
}
