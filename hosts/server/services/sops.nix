# sops.nix — segredos do servidor (age = chave SSH do host)
#
# Este módulo NÃO está importado por padrão. Para ativar:
#
#   1. crie hosts/server/secrets/server.yaml cifrado
#      (veja hosts/server/secrets/README.md);
#   2. no flake.nix, descomente sops-nix.nixosModules.sops;
#   3. adicione ./sops.nix aos imports de services/default.nix;
#   4. troque os tokens manuais:
#      - ci-runner.nix: tokenFile = "/run/secrets/forgejo-runner.env";
#      - comin.nix: access_token_path e ConditionPathExists para
#        "/run/secrets/comin-token";
#   5. valide com `sops -d hosts/server/secrets/server.yaml` e rebuild.
#
# A chave age é a host key SSH (/etc/ssh/ssh_host_ed25519_key). Faça backup
# dela: se for regenerada, os segredos ficam irrecuperáveis.

{ config, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/server.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."comin-token" = { };
    secrets."forgejo-runner-token" = { };

    templates."forgejo-runner.env" = {
      content = "TOKEN=${config.sops.placeholder."forgejo-runner-token"}";
      path = "/run/secrets/forgejo-runner.env";
    };
  };
}
