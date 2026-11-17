# comin.nix — CD GitOps para o NixOS (pull a cada 30s)
#
# O comin roda como root no próprio servidor, busca a branch main do repo
# no Forgejo, builda nixosConfigurations.server e aplica com
# switch-to-configuration. O CI (Forgejo Actions) só valida/builda.
#
# - main            -> switch (atualiza bootloader + runtime)
# - testing-server   -> test   (runtime only; não mexe no bootloader)
#
# Token (bootstrap manual):
#   sudo install -d -m 0700 /etc/comin
#   sudo install -m 0400 /dev/null /etc/comin/token
#   sudo nano /etc/comin/token   # token read-only do Forgejo
#   sudo systemctl start comin
#
# TODO(sops): depois de criar hosts/server/secrets/server.yaml e importar
# sops.nix, troque access_token_path e ConditionPathExists para
# "/run/secrets/comin-token".

{ config, lib, pkgs, ... }:
let
  healthcheck = pkgs.writeShellApplication {
    name = "comin-healthcheck";
    runtimeInputs = with pkgs; [ coreutils curl systemd util-linux ];
    text = ''
      set -eu
      [ "''${COMIN_STATUS:-}" = "done" ] || exit 0

      wait_http() {
        for _ in $(seq 1 30); do
          curl -fsS --max-time 5 "$1" >/dev/null && return 0
          sleep 2
        done
        return 1
      }

      wait_unit() {
        for _ in $(seq 1 30); do
          systemctl is-active --quiet "$1" && return 0
          sleep 2
        done
        return 1
      }

      fail=0
      wait_http http://127.0.0.1:3001/api/healthz || fail=1
      wait_http http://127.0.0.1:8082/ || fail=1
      wait_http http://127.0.0.1:19999/api/v1/info || fail=1
      wait_http http://127.0.0.1:28981/ || fail=1
      wait_http http://127.0.0.1:3002/api/health || fail=1
      wait_http http://127.0.0.1:9090/-/ready || fail=1
      wait_http http://127.0.0.1:3100/ready || fail=1

      for unit in \
        nginx forgejo mysql sshd dnsmasq glance netdata paperless-web loki alloy
      do
        wait_unit "$unit" || fail=1
      done

      # O runner pode estar intencionalmente parado enquanto o token não existe.
      if [ -e /etc/forgejo-runner/token.env ]; then
        wait_unit gitea-runner-local || fail=1
      fi

      if [ "$fail" -ne 0 ]; then
        logger -t comin-health "healthcheck falhou no commit ''${COMIN_GIT_SHA:-?}"
        exit 1
      fi
    '';
  };
in
{
  services.comin = {
    enable = true;

    # Atributo nixosConfigurations.server (não é o hostname da máquina).
    hostname = "server";

    remotes = [
      {
        name = "origin";
        url = "http://127.0.0.1:3001/homelab/nix-config.git";

        auth = {
          username = "gipsydanger";
          access_token_path = "/etc/comin/token";
        };

        branches = {
          main = {
            name = "main";
            operation = "switch";
          };
          testing = {
            name = "testing-server";
            operation = "test";
          };
        };

        poller.period = 30;
      }
    ];

    buildAttemptsLimit = 3;
    buildRetryTimer = 60;
    buildTimeout = 3600;

    postDeploymentCommand = "${healthcheck}/bin/comin-healthcheck";

    exporter = {
      listen_address = "127.0.0.1";
      port = 4243;
    };

    retention = {
      deployment_any_capacity = 10;
      deployment_successful_capacity = 5;
      deployment_boot_entry_capacity = 5;
    };
  };

  systemd.services.comin = {
    after = [
      "forgejo.service"
      "sops-install-secrets.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];

    # Se o comin shell out para git, garanta o binário no PATH.
    path = lib.mkAfter [ pkgs.git ];

    # Não inicia enquanto o token não existir.
    unitConfig.ConditionPathExists = "/etc/comin/token";
  };
}
