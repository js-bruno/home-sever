# ci-runner.nix — Forgejo Actions runner em host mode (sem sudo)
#
# O runner só valida/builda o flake. Quem aplica a config é o comin
# (ver comin.nix); portanto não há sudo nem usuário estático aqui.
#
# Token (bootstrap manual):
#   sudo install -d -m 0700 /etc/forgejo-runner
#   sudo sh -c 'printf "TOKEN=%s\n" "SEU_TOKEN" > /etc/forgejo-runner/token.env'
#   sudo chmod 0400 /etc/forgejo-runner/token.env
#   sudo systemctl start gitea-runner-local
#
# TODO(sops): depois de criar hosts/server/secrets/server.yaml e importar
# sops.nix, troque tokenFile para "/run/secrets/forgejo-runner.env".

{ pkgs, lib, ... }:
{
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.local = {
      enable = true;
      name = "shatterdome";
      url = "http://127.0.0.1:3001";
      tokenFile = "/etc/forgejo-runner/token.env";
      labels = [ "nixos:host" ];

      hostPackages = with pkgs; [
        bash
        coreutils
        curl
        gawk
        gitMinimal
        gnused
        nodejs_22
        wget
        nix
        openssh
        gnutar
        gzip
        jq
        cacert
      ];

      settings.runner.capacity = 1;
    };
  };

  # Não entra em loop enquanto o token não existir.
  systemd.services.gitea-runner-local.unitConfig.ConditionPathExists =
    "/etc/forgejo-runner/token.env";
}
