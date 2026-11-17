# forgejo.nix — forge Git self-hosted, acesso EXCLUSIVO pela LAN.
#
# Escopo intencionalmente mínimo: não mexe em nginx, WireGuard/VPS, rotas,
# regras globais de firewall nem na configuração do sshd.
#
# - Escuta em 0.0.0.0:3001; o loopback continua valendo para comin, runner e
#   Prometheus (quando existirem).
# - Entrypoint único: http://192.168.15.50:3001 (sem DNS, sem nginx, sem URL
#   pública).
# - Firewall: 3001 liberado SÓ na interface da LAN (enp3s0). Isso funciona no
#   backend iptables atual (a regra vira `-i enp3s0 --dport 3001 ACCEPT`),
#   não abre porta global e não altera a regra do SSH (2222 fica como está
#   em ssh.nix).
# - SSH do Forgejo desabilitado: clone/push só por HTTPS (token).
#
# Bootstrap: o primeiro usuário criado pela LAN vira admin. Depois disso,
# troque DISABLE_REGISTRATION para true.

{ lib, pkgs, ... }:
let
  port = 3001;
  lanAddress = "192.168.15.50";
in
{
  services.forgejo = {
    enable = true;
    package = pkgs.forgejo-lts;
    database.type = "sqlite3";
    lfs.enable = true;

    dump = {
      enable = true;
      interval = "04:31";
      age = "4w";
    };

    settings = {
      server = {
        DOMAIN = lanAddress;
        ROOT_URL = "http://${lanAddress}:${toString port}/";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = port;
        DISABLE_SSH = true;
        OFFLINE_MODE = true;
      };

      actions = {
        ENABLED = true;
        ARTIFACT_RETENTION_DAYS = 14;
      };

      # Prometheus (quando ligado) raspa http://127.0.0.1:3001/metrics.
      metrics = {
        ENABLED = true;
        ENABLED_ISSUE_BY_REPOSITORY = true;
      };

      packages = {
        ENABLED = true;
        LIMIT_TOTAL_OWNER_SIZE = "20 GiB";
        LIMIT_SIZE_CONTAINER = "2 GiB";
      };

      "cron.cleanup_packages" = {
        SCHEDULE = "@midnight";
        OLDER_THAN = "720h";
      };

      service = {
        # TODO: depois de criar o admin, mude para true e rebuild.
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = true;
      };

      # Acesso é HTTP na LAN, sem TLS local.
      session.COOKIE_SECURE = false;

      ui.DEFAULT_THEME = "forgejo-auto";
    };
  };

  # O módulo do Forgejo injeta `AcceptEnv GIT_PROTOCOL` no sshd quando o SSH
  # embutido está desligado. Isso mudaria /etc/ssh/sshd_config e faria o sshd
  # reiniciar no switch. Como usamos só HTTPS e o SSH do Forgejo está
  # desabilitado, forçamos o valor atual (null = a linha não é gerada) para o
  # sshd_config ficar byte a byte idêntico e o sshd não ser tocado.
  services.openssh.settings.AcceptEnv = lib.mkForce null;

  # Única alteração de rede: 3001 aceito na NIC da LAN, nada global.
  networking.firewall.interfaces.enp3s0.allowedTCPPorts = [ port ];
}
