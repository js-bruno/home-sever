# Segredos do servidor (sops-nix)

Este diretório guarda **apenas** o arquivo cifrado `server.yaml`.
O `server.yaml.example` é só um modelo, sem valores reais.

## 1. Descobrir o recipient age

A chave age é a host key SSH do `shatterdome`:

```bash
nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
```

Copie o `age1...` e substitua o placeholder em `.sops.yaml` na raiz do repo.

> Faça backup de `/etc/ssh/ssh_host_ed25519_key`. Sem ela, os segredos são
> irrecuperáveis.

## 2. Criar e cifrar o arquivo

```bash
cd ~/.config/nix-config
cp hosts/server/secrets/server.yaml.example hosts/server/secrets/server.yaml
sops hosts/server/secrets/server.yaml
```

Preencha:

```yaml
comin-token: "token read-only do Forgejo (read:repository)"
forgejo-runner-token: "token de registro do runner da org homelab"
```

Salve; o `sops` cifra o arquivo usando a regra de `.sops.yaml`.

Valide:

```bash
sops -d hosts/server/secrets/server.yaml >/dev/null && echo OK
```

## 3. Ativar o módulo

1. `flake.nix`: descomente `sops-nix.nixosModules.sops`.
2. `hosts/server/services/default.nix`: adicione `./sops.nix`.
3. `ci-runner.nix`: `tokenFile = "/run/secrets/forgejo-runner.env";`
4. `comin.nix`: `access_token_path = "/run/secrets/comin-token";` e
   `ConditionPathExists = "/run/secrets/comin-token";`
5. Rebuild.

## 4. Backup

Além da host key, guarde uma cópia do `server.yaml` cifrado e do recipient
em local seguro. O dump do Forgejo não inclui estes segredos.
