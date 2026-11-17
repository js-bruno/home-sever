# Runbook — Forgejo + CI + comin no `shatterdome`

> **Para o agente que vai executar:** este guia foi escrito para ser seguido no servidor
> `shatterdome` (192.168.15.50), dentro do repo `~/.config/nix-config`.
> O agente **não deve** tocar em `/dev/sda`, não deve reparticionar nada e não deve
> commitar segredos em texto plano. O usuário `gipsydanger` **não tem sudo sem senha**:
> prepare e valide as mudanças e peça ao usuário para rodar os comandos `sudo`.

---

## 0. Contexto fixo

| Item | Valor |
|---|---|
| Host | `shatterdome` / `192.168.15.50` |
| SSH | porta `2222`, usuário `gipsydanger` |
| Repo no servidor | `~/.config/nix-config` |
| Flake | `nixosConfigurations.server` |
| NixOS | 26.05 (flake) |
| `/etc/nixos` | **stale**; sempre use `--flake .#server` |
| CPU | Intel Pentium G620, 2 núcleos, sem AVX |
| RAM | 7.6 GiB |
| Disco do NixOS | `/dev/sdb2`, 139 GB ext4, ~52 GB livres |
| Disco intocável | `/dev/sda`, 465 GB NTFS (não está no `nix-config`) |
| Web | nginx na 80/443; VPS faz TLS público |
| VPS | `191.252.38.145`, WireGuard `10.88.88.1`, domínio `thisdev.space` |
| Serviços atuais | nginx, mysql, habbo, paperless, glance, netdata, excalidraw, dnsmasq, fail2ban |
| Porta da forge | `127.0.0.1:3001` (já liberada na LAN no firewall) |

### Decisões já tomadas

- **Forgejo LTS** + SQLite + Forgejo Actions.
- **Runner host mode**, `DynamicUser`, **sem sudo**.
- **comin** para deploy (pull a cada 30 s) + deploy manual por SSH em emergência.
- **sops-nix** com a chave SSH do host como age.
- **Apps Nix-native** (flake + `nixosModules`) na fase futura; **não** OCI como padrão.
- **Não** reparticionar o `sda`; a forge fica em `/var/lib/forgejo` no `sdb2`.
- Org do Forgejo: `homelab`; repo `nix-config`.

### Estado atual do repo (já implementado)

| Arquivo | Estado |
|---|---|
| `flake.nix` | inputs `comin`/`sops-nix`; `comin.nixosModules.comin` importado; módulo do sops comentado |
| `hosts/server/services/forgejo.nix` | implementado (bootstrap LAN; TODO de VPS/HTTPS) |
| `hosts/server/services/ci-runner.nix` | implementado; token manual em `/etc/forgejo-runner/token.env` |
| `hosts/server/services/comin.nix` | implementado; token manual em `/etc/comin/token` |
| `hosts/server/services/sops.nix` | template pronto; **não importado** |
| `hosts/server/services/observability.nix` | Prometheus + node_exporter + Loki + Alloy + Grafana LAN-only |
| `hosts/server/services/grafana-dashboard.json` | dashboard provisionado (métricas + logs) |
| `hosts/server/services/service-watch.py` | monitora Forgejo/comin/runner/Grafana/Prometheus/node/Loki/Alloy |
| `hosts/server/services/default.nix` | importa forgejo/runner/comin/observability; sops comentado |
| `hosts/server/services/dnsmasq.nix` | Forgejo não depende mais de alias DNS local |
| `hosts/server/setup-vps-forgejo.sh` | implementado |
| `.forgejo/workflows/ci.yml` | implementado |
| `.sops.yaml` + `hosts/server/secrets/*` | modelo/placeholder; falta criar o `server.yaml` cifrado |
| `AGENTS.md` / `docs/agent-deploy.md` | este guia |

### O que ainda falta criar (manual, fora do Nix)

1. Admin do Forgejo (primeiro usuário) e org `homelab`.
2. Repo `homelab/nix-config` migrado do GitHub.
3. Token read-only do comin → `/etc/comin/token`.
4. Token de registro do runner → `/etc/forgejo-runner/token.env`.
5. Registro DNS `git.thisdev.space` → IP da VPS.
6. Rodar `setup-vps-forgejo.sh` na VPS e ajustar `ROOT_URL`/`COOKIE_SECURE`.
7. (Opcional/futuro) criar `hosts/server/secrets/server.yaml` cifrado com sops,
   importar `sops.nix` e trocar os tokens manuais pelos paths do sops.
8. Acessar o Grafana em `http://192.168.15.50:3002` e guardar a senha gerada
   em `/var/lib/grafana/admin-password`.

---

## 1. Pré-requisitos

- [ ] Backup da host key SSH do servidor (`/etc/ssh/ssh_host_ed25519_key`). Ela será a
      identidade age do sops; se for regenerada, os segredos ficam irrecuperáveis.
- [ ] Acesso à VPS para rodar o script de nginx/certbot.
- [ ] Registro DNS `git.thisdev.space` apontando para o IP da VPS.
- [ ] Acesso de admin ao Forgejo (o primeiro usuário criado vira admin).
- [ ] Confirmar que o `sda` de 465 GB **não** será tocado.

---

## 2. Baseline (antes de mudar qualquer coisa)

```bash
cd ~/.config/nix-config
git status
git log --oneline -3
nix flake show
nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link
df -h /
systemctl --failed --no-pager
nix-env --list-generations -p /nix/var/nix/profiles/system | tail -5
```

Se o build falhar, **pare** e resolva antes de continuar.

Anote a geração atual para rollback:

```bash
readlink /nix/var/nix/profiles/system
```

---

## 3. Arquivos implementados/pendentes

| Arquivo | Ação |
|---|---|
| `flake.nix` | inputs `comin`/`sops-nix`; `comin.nixosModules.comin` importado; sops comentado |
| `hosts/server/services/forgejo.nix` | implementado (LAN bootstrap; TODO VPS) |
| `hosts/server/services/ci-runner.nix` | implementado (token manual) |
| `hosts/server/services/comin.nix` | implementado (token manual) |
| `hosts/server/services/sops.nix` | template; não importado |
| `hosts/server/services/default.nix` | importa forgejo/runner/comin; sops comentado |
| `hosts/server/services/dnsmasq.nix` | Forgejo não depende mais de alias DNS local |
| `hosts/server/setup-vps-forgejo.sh` | implementado |
| `.forgejo/workflows/ci.yml` | implementado |
| `.sops.yaml` | placeholder; substituir o recipient age |
| `hosts/server/secrets/server.yaml` | **falta criar/cifrar** |
| `README.md` | opcional |

---

## 4. Fase 1 — Forgejo na LAN

### 4.1 Criar `hosts/server/services/forgejo.nix`

```nix
{ config, lib, pkgs, ... }:
let
  port = 3001;
  domain = "git.thisdev.space";
  lanAlias = "192.168.15.50";
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
        DOMAIN = domain;
        # Acesso LAN direto por IP, sem depender de DNS local.
        # Depois da VPS: "https://git.thisdev.space/".
        ROOT_URL = "http://192.168.15.50/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = port;
        DISABLE_SSH = true;
        OFFLINE_MODE = true;
      };

      actions = {
        ENABLED = true;
        ARTIFACT_RETENTION_DAYS = 14;
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
        # Primeira subida: false, para criar o admin.
        # Depois de criar o admin: true.
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = true;
      };

      session.COOKIE_SECURE = false; # true depois da VPS/HTTPS

      ui.DEFAULT_THEME = "forgejo-auto";
    };
  };

  # Preserva X-Forwarded-Proto da VPS; LAN direta usa $scheme.
  services.nginx.appendHttpConfig = ''
    map $http_x_forwarded_proto $forgejo_proto {
      default $http_x_forwarded_proto;
      "" $scheme;
    }
  '';

  services.nginx.virtualHosts.${domain} = {
    serverAliases = [ lanAlias ];

    locations."/" = {
      # proxy_pass manual para não herdar o X-Forwarded-Proto=$scheme
      # do recommendedProxyConfig do módulo do nginx.
      extraConfig = ''
        proxy_pass http://127.0.0.1:${toString port};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $forgejo_proto;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        client_max_body_size 2g;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;

        allow 10.88.88.1;
        allow 192.168.15.0/24;
        allow 127.0.0.1;
        deny all;
      '';
    };
  };
}
```

> Não defina `proxyWebsockets = true` junto com o `proxy_pass` manual: o módulo do
> nginx já cria o map `$connection_upgrade`, e nós usamos esse map diretamente.

### 4.2 Acesso local

Não há alias DNS do Forgejo. Qualquer dispositivo na LAN acessa diretamente
`http://192.168.15.50/`; não precisa alterar DNS nem o arquivo `hosts`.

### 4.3 Importar o módulo

Em `hosts/server/services/default.nix`:

```nix
imports = [
  ./ssh.nix
  ./minecraft.nix
  ./paperless.nix
  ./glance.nix
  ./netdata.nix
  ./hotel-vhost.nix
  ./reverse-proxy.nix
  ./dnsmasq.nix
  ./excalidraw.nix
  ./service-metrics.nix
  ./service-watch.nix
  ./forgejo.nix
];
```

### 4.4 Validar

```bash
cd ~/.config/nix-config
nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link
```

### 4.5 Aplicar (pedir ao usuário)

```bash
sudo nixos-rebuild switch --flake .#server
```

### 4.6 Pós-deploy

```bash
systemctl status forgejo --no-pager
curl -fsS http://127.0.0.1:3001/api/healthz
journalctl -u forgejo -n 50 --no-pager
```

Na rede local, abra `http://192.168.15.50/` diretamente; não precisa configurar DNS nem editar o arquivo hosts.

1. Crie o primeiro usuário: ele vira admin.
2. Crie a organização `homelab`.
3. Migre o repo do GitHub:
   - **New Migration** → GitHub → `js-bruno/home-sever`;
   - nome no Forgejo: `nix-config`.
   - Se preferir CLI:
     ```bash
     git clone --mirror git@github.com:js-bruno/home-sever.git /tmp/nix-config.git
     cd /tmp/nix-config.git
     git push --mirror http://gipsydanger:TOKEN@192.168.15.50:3001/homelab/nix-config.git
     ```
4. Configure **push mirror** para o GitHub (opcional, mas recomendado).
5. Edite `hosts/server/services/forgejo.nix`:
   - `DISABLE_REGISTRATION = true;`
6. Rebuild manual (usuário):
   ```bash
   sudo nixos-rebuild switch --flake .#server
   ```

### 4.7 Atualizar os remotes locais

No repo do servidor e no desktop:

```bash
git remote rename origin github
git remote add origin http://192.168.15.50:3001/homelab/nix-config.git
git push -u origin main
```

Use um **token** do Forgejo como senha no HTTPS. Não deixe o token em texto plano
no histórico nem em arquivo versionado.

---

## 5. Fase 2 — VPS/HTTPS

### 5.1 DNS

Crie o registro **A** `git.thisdev.space` → IP da VPS.

### 5.2 Criar `hosts/server/setup-vps-forgejo.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-thisdev.space}"
SUB="${2:-git}"
SITE="/etc/nginx/sites-available/${SUB}.${DOMAIN}"

if [ "$(id -u)" -ne 0 ]; then
  echo "rode como root na VPS" >&2
  exit 1
fi

apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

cat > "$SITE" <<EOF
server {
    listen 80;
    server_name ${SUB}.${DOMAIN};
    client_max_body_size 2g;

    location / {
        proxy_pass http://10.88.88.2:80;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

ln -sf "$SITE" "/etc/nginx/sites-enabled/${SUB}.${DOMAIN}"
nginx -t
systemctl reload nginx

certbot --nginx -d "${SUB}.${DOMAIN}" \
  --non-interactive --agree-tos --redirect \
  -m "admin@${DOMAIN}" || {
    echo "AVISO: certbot falhou; confira o DNS A de ${SUB}.${DOMAIN}" >&2
    exit 1
  }

echo "OK: https://${SUB}.${DOMAIN}"
```

Rodar na VPS (usuário):

```bash
sudo bash setup-vps-forgejo.sh thisdev.space git
```

### 5.3 Ajustar o Forgejo para HTTPS

Depois que `https://git.thisdev.space` responder:

```nix
server.ROOT_URL = "https://git.thisdev.space/";
session.COOKIE_SECURE = true;
security = {
  REVERSE_PROXY_LIMIT = 2;
  REVERSE_PROXY_TRUSTED_PROXIES = "127.0.0.1,10.88.88.1";
};
```

Validar, aplicar e testar:

```bash
curl -I https://git.thisdev.space
curl -I http://192.168.15.50
```

> O acesso local é direto pelo IP `192.168.15.50`; não há alias DNS privado para Forgejo.

---

## 6. Fase 3 — sops-nix (opcional/futuro)

> O input `sops-nix` **já está** no `flake.nix`, mas o módulo e o
> `hosts/server/services/sops.nix` estão comentados de propósito para o build
> não depender de um arquivo cifrado que ainda não existe. A implementação
> atual usa tokens manuais (`/etc/comin/token` e
> `/etc/forgejo-runner/token.env`). Siga esta fase quando quiser migrar para
> sops.

### 6.1 Descobrir o recipient age

```bash
nix run nixpkgs#ssh-to-age -- -i /etc/ssh/ssh_host_ed25519_key.pub
```

Guarde o valor `age1...`.

### 6.2 `.sops.yaml` na raiz do repo

```yaml
keys:
  - &shatterdome age1SUBSTITUA_PELA_CHAVE

creation_rules:
  - path_regex: hosts/server/secrets/.*\.yaml$
    key_groups:
      - age:
          - *shatterdome
```

### 6.3 Criar o arquivo de segredos

```bash
mkdir -p hosts/server/secrets
sops hosts/server/secrets/server.yaml
```

Conteúdo (o `sops` cifra ao salvar):

```yaml
comin-token: "TOKEN_READ_ONLY_DO_FORGEJO"
forgejo-runner-token: "TOKEN_DE_REGISTRO_DO_RUNNER"
```

- `comin-token`: User Settings → Applications → Generate token; escopo
  `read:repository`.
- `forgejo-runner-token`: Settings da org `homelab` → Actions → Runners →
  Create new runner.

### 6.4 `hosts/server/services/sops.nix`

```nix
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
```

### 6.5 `flake.nix` — módulo (input já existe)

O input já está no `flake.nix`; falta **descomentar** o módulo:

```nix
modules = [
  ./hosts/server/configuration.nix
  comin.nixosModules.comin
  sops-nix.nixosModules.sops   # descomente
  # ...
];
```

Adicione `./sops.nix` ao `services/default.nix` e valide:

```bash
nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link
sops -d hosts/server/secrets/server.yaml >/dev/null && echo OK
```

> Se o arquivo `server.yaml` não existir, o build falha na avaliação. Crie-o
> antes de importar o módulo.

---

## 7. Fase 4 — Runner + CI

### 7.1 `hosts/server/services/ci-runner.nix`

```nix
{ pkgs, ... }:
{
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;

    instances.local = {
      enable = true;
      name = "shatterdome";
      url = "http://127.0.0.1:3001";
      # Bootstrap manual; na fase sops troque para
      # "/run/secrets/forgejo-runner.env".
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
```

Crie o token antes de iniciar:

```bash
sudo install -d -m 0700 /etc/forgejo-runner
sudo sh -c 'printf "TOKEN=%s\n" "SEU_TOKEN" > /etc/forgejo-runner/token.env'
sudo chmod 0400 /etc/forgejo-runner/token.env
sudo systemctl start gitea-runner-local
```

Adicione ao `services/default.nix` e valide.

### 7.2 Aplicar e verificar

```bash
sudo nixos-rebuild switch --flake .#server
systemctl status gitea-runner-local --no-pager
journalctl -u gitea-runner-local -n 50 --no-pager
```

No Forgejo, o runner deve aparecer online na org `homelab`.

### 7.3 `.forgejo/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  eval:
    runs-on: nixos
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - name: Avaliar config do servidor
        run: nix eval --raw .#nixosConfigurations.server.config.system.build.toplevel.drvPath

  build:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: eval
    runs-on: nixos
    timeout-minutes: 90
    steps:
      - uses: actions/checkout@v4
      - name: Build da config
        run: nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link --max-jobs 1
```

### 7.4 Testar

- Abra um PR com um erro de avaliação de propósito; o job `eval` deve falhar.
- Remova o erro; o job deve passar.
- Faça merge na `main`; o job `build` deve rodar.

---

## 8. Fase 5 — comin

### 8.1 `hosts/server/services/comin.nix`

```nix
{ config, lib, pkgs, ... }:
let
  healthcheck = pkgs.writeShellApplication {
    name = "comin-healthcheck";
    runtimeInputs = with pkgs; [ curl systemd util-linux ];
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

      for unit in \
        nginx forgejo mysql sshd dnsmasq glance netdata paperless-web
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

    # nixosConfigurations.server (não é o hostname da máquina)
    hostname = "server";

    remotes = [
      {
        name = "origin";
        url = "http://127.0.0.1:3001/homelab/nix-config.git";

        auth = {
          username = "gipsydanger";
          # Bootstrap manual; na fase sops troque para
          # "/run/secrets/comin-token".
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
    after = [ "forgejo.service" "sops-install-secrets.service" "network-online.target" ];
    wants = [ "network-online.target" ];

    # Se o comin shell out para git, garanta o binário no PATH.
    path = lib.mkAfter [ pkgs.git ];

    unitConfig.ConditionPathExists = "/etc/comin/token";
  };
}
```

Crie o token antes de iniciar:

```bash
sudo install -d -m 0700 /etc/comin
sudo install -m 0400 /dev/null /etc/comin/token
sudo nano /etc/comin/token   # token read-only do Forgejo
sudo systemctl start comin
```

### 8.2 `flake.nix` — input e módulo

```nix
inputs = {
  # ...
  comin = {
    url = "github:nlewo/comin";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

outputs = { self, nixpkgs, home-manager, hermes-agent, nix-minecraft, habbo-nixos, comin, sops-nix, ... }@inputs:
# ...
modules = [
  ./hosts/server/configuration.nix
  comin.nixosModules.comin
  sops-nix.nixosModules.sops
  # ...
];
```

> Se o build do comin falhar com o nixpkgs 26.05, remova
> `inputs.nixpkgs.follows = "nixpkgs"` do input `comin` e deixe ele usar o
> nixpkgs próprio. O binário é pequeno; o custo é ter outro nixpkgs no store.

Adicione `./comin.nix` ao `services/default.nix`.

### 8.3 Validar e aplicar

```bash
nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link
sudo nixos-rebuild switch --flake .#server
```

**Antes de aplicar**, confirme que o commit com essas mudanças já está na `main`
do Forgejo. Se o comin iniciar e a `main` remota estiver atrás, ele pode deployar
uma config sem o próprio comin.

```bash
git push origin main
```

### 8.4 Verificar

```bash
systemctl status comin --no-pager
comin status --oneline
journalctl -u comin -n 50 --no-pager
```

### 8.5 Testar canary

```bash
git switch -c testing-server
# faça uma mudança trivial, por exemplo um comentário
git commit -am "test: comin canary"
git push origin testing-server
```

O comin deve rodar `switch-to-configuration test` (sem mudar o bootloader):

```bash
comin status --oneline
journalctl -u comin -f
```

Se estiver ok:

```bash
git switch main
git merge --ff-only testing-server
git push origin main
git push origin --delete testing-server
```

O comin deve deployar a `main` com `switch`.

### 8.6 Testar rollback

```bash
sudo nixos-rebuild switch --rollback
```

Confirme que os serviços voltam. Depois, se quiser, faça o deploy da `main` de novo
(comin pega no próximo poll) ou `sudo nixos-rebuild switch --flake .#server`.

> Auto-rollback em falha de healthcheck **não** é nativo do comin. O healthcheck
> só registra no journal/Netdata. Se quiser rollback automático depois, faça um
> script destacado via `systemd-run` que roda `comin suspend` +
> `nixos-rebuild switch --rollback`. Não habilite isso antes de estabilizar o fluxo.

---

## 9. Fase 6 — Operação

### 9.1 Nix GC e limites

Em `hosts/server/services/comin.nix` ou em um módulo de ops:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

nix.settings.min-free = 10 * 1024 * 1024 * 1024;
nix.settings.max-jobs = 1; # protege o hotel/Paperless
```

- `nix.settings.max-jobs = 1` deixa um build por vez; `cores` pode usar os 2.
- Não habilite `auto-optimise-store` no G620/HDD.

### 9.2 Forgejo

- `ARTIFACT_RETENTION_DAYS = 14` (já no módulo).
- `cron.cleanup_packages` diário.
- `LIMIT_TOTAL_OWNER_SIZE = 20 GiB`.
- Dump diário em `/var/lib/forgejo/dump` + cópia offsite (restic/desktop).
- Push mirror para o GitHub.

### 9.3 Monitoração

- Netdata já roda; monitore `/` e `/nix`.
- **Grafana + Prometheus + Loki + Alloy** implementados em
  `observability.nix`:
  - Grafana: `http://192.168.15.50:3002` (LAN-only; 3002 no firewall LAN).
  - Prometheus: `127.0.0.1:9090`, retenção `7d` / `2GB`.
  - node_exporter: `127.0.0.1:9100` (coletor systemd).
  - Loki: `127.0.0.1:3100`, retenção `7d` em `/var/lib/loki`.
  - Alloy: lê o journal de Forgejo/comin/runner/nginx/Grafana/Prometheus e
    envia para o Loki; API local em `127.0.0.1:12345`.
  - Scrapes: node, Forgejo (`/metrics`), comin (`4243`) e o próprio Prometheus.
  - Dashboard `Shatterdome` provisionado via `grafana-dashboard.json`
    (métricas + painel de logs do Loki).
- Senha inicial do Grafana (gerada no primeiro start):
  `sudo cat /var/lib/grafana/admin-password`.
- Para resetar a senha:
  `sudo -u grafana grafana cli admin reset-admin-password NOVA_SENHA`.
- O `service-watch` agora cobre Forgejo, comin, runner, Grafana, Prometheus,
  node_exporter, Loki e Alloy. Comin/runner ficam em falha até os tokens.
- Glance: links para Forgejo e Grafana na aba Homelab.

### 9.4 Segurança

- Forgejo: registro fechado, 2FA no admin, branch `main` protegida, status checks.
- Runner: sem sudo, `DynamicUser`, `capacity=1`, escopo de org.
- comin: token read-only; `ConditionPathExists`; logs no journal.
- VPS: fail2ban/rate limit no login; TLS; `client_max_body_size` limitado.
- Não expor 3001/3002/9090/3100/12345 publicamente; Forgejo só via nginx/VPS,
  Grafana/Prometheus só na LAN e Loki/Alloy só em loopback.
- sops: host key com backup; segredos cifrados no repo.

### 9.5 Assinatura de commits (opcional, fase futura)

Só ative depois que o fluxo estiver estável:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

```nix
services.comin.sshAllowedSignersPath = "/etc/comin/allowed_signers";
# arquivo: voce@exemplo.com ssh-ed25519 AAAAC3...
```

Com isso, todo commit que chega na `main` precisa estar assinado. Se ativar,
configure também o Forgejo para mostrar a chave como signing key.

---

## 10. Fase 7 — Apps (futuro, não implementar agora)

O padrão escolhido é **Nix-native híbrido**:

| Necessidade | Solução |
|---|---|
| App simples, sem root | `systemd.services` + sandbox (`DynamicUser`, `ProtectSystem`, `StateDirectory`) |
| App precisa de root/deps conflitantes | `containers.<name>` (systemd-nspawn) |
| Código não confiável | `microvm.nix` (opcional, pesado) |
| Imagem de terceiro | `virtualisation.oci-containers` |

### Padrão por app

1. Repo do app ganha `flake.nix` com:
   - `packages.<system>.default` (`buildGoModule`, `buildNpmPackage`, etc.);
   - `nixosModules.default` com opções e o serviço.
2. Infra adiciona o input pinado:
   ```nix
   inputs.chat = {
     url = "git+http://127.0.0.1:3001/homelab/chat-websocket-go";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
3. Infra importa `inputs.chat.nixosModules.default` e ativa `services.chat.enable`.
4. Comin deploya o host inteiro; rollback é a geração anterior.
5. Dados em `StateDirectory`; segredos via sops; nginx na frente.
6. Atualização: `nix flake update chat` ou Renovate no Forgejo.
7. Builds pesados: Attic/Harmonia + remote builder no desktop.

Exemplo de módulo Go:

```nix
nixosModules.default = { config, lib, pkgs, ... }: {
  options.services.chat = {
    enable = lib.mkEnableOption "chat";
    port = lib.mkOption { type = lib.types.port; default = 8080; };
  };

  config = lib.mkIf config.services.chat.enable {
    systemd.services.chat = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${self.packages.${pkgs.system}.default}/bin/chat";
        DynamicUser = true;
        StateDirectory = "chat";
        Restart = "always";
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      environment.PORT = toString config.services.chat.port;
    };

    services.nginx.virtualHosts."chat.thisdev.space" = {
      locations."/".proxyPass =
        "http://127.0.0.1:${toString config.services.chat.port}";
    };
  };
};
```

Sites estáticos: `buildNpmPackage`/`stdenv.mkDerivation` e
`services.nginx.virtualHosts.<site>.root = "${pkg}";` — sem rsync, sem `/srv/www`.

**Não implementar apps nesta fase.** O foco é a infra.

---

## 11. Troubleshooting

| Sintoma | Verificar |
|---|---|
| Forgejo não sobe | `journalctl -u forgejo`; permissões de `/var/lib/forgejo`; `services.forgejo` |
| Nginx 502 | `ss -tlnp | grep 3001`; Forgejo ativo; vhost/Host |
| Login redireciona errado | `ROOT_URL` e `COOKIE_SECURE`; `X-Forwarded-Proto` |
| Runner offline | token de registro; `journalctl -u gitea-runner-local`; label `nixos:host` |
| CI falha no checkout | token do job; permissões do repo; `actions/checkout@v4` |
| comin não deploya | `comin status`; token; URL; `ConditionPathExists`; `journalctl -u comin` |
| comin build falha | rode `nix build ...` manual; disco; GC; `max-jobs` |
| sops não decrypta | host key SSH; recipient age; `sops -d`; `systemctl status sops-install-secrets` |
| Disco cheio | `nix-collect-garbage -d` (cuidado), `nix.gc`, dumps, Forgejo cleanup |
| Deploy ruim | `comin suspend`; `sudo nixos-rebuild switch --rollback`; menu do boot |
| VPS 502 | WireGuard; `10.88.88.2:80`; Host header; cert |

### Comandos úteis

```bash
comin status --oneline
comin suspend
comin resume
journalctl -u comin -f
journalctl -u forgejo -f
systemctl list-timers --all
nix-env --list-generations -p /nix/var/nix/profiles/system
readlink /nix/var/nix/profiles/system
```

---

## 12. Rollback

1. **Infra**: `sudo nixos-rebuild switch --rollback` ou escolha a geração no
   systemd-boot.
2. **comin**: `comin suspend` antes de mexer; `comin resume` depois.
3. **Forgejo**: restaurar dump (`forgejo dump` gera; restore documentado no admin).
4. **Código**: o GitHub mirror continua existindo; o Forgejo é a fonte primária.
5. **Manual**: se comin/forge caírem, `sudo nixos-rebuild switch --flake ~/.config/nix-config#server`.

---

## 13. Checklist final

- [ ] `sda` de 465 GB intocado.
- [ ] `nix build .#nixosConfigurations.server...` passa.
- [ ] Forgejo na LAN (`http://192.168.15.50`).
- [ ] Admin criado; registro fechado.
- [ ] Org `homelab` e repo `nix-config` migrados.
- [ ] VPS `https://git.thisdev.space` com cert válido.
- [ ] `ROOT_URL` https e `COOKIE_SECURE=true`.
- [ ] Token do runner em `/etc/forgejo-runner/token.env`.
- [ ] Token do comin em `/etc/comin/token`.
- [ ] Grafana em `http://192.168.15.50:3002` (senha em `/var/lib/grafana/admin-password`).
- [ ] Prometheus com targets node/forgejo/comin UP.
- [ ] Loki/Alloy ativos; painel de logs do dashboard mostrando entradas.
- [ ] Runner online; CI eval/build funcionando.
- [ ] comin ativo; `testing-server` testado; `main` deployada.
- [ ] Rollback testado.
- [ ] GC/limites/backups/monitoração.
- [ ] (Opcional) sops-nix decryptando e tokens migrados.
- [ ] README atualizado.

---

## 14. Proibições

- **Não** tocar em `/dev/sda` (465 GB NTFS) nem reparticionar.
- **Não** mover `/nix` nem usar o layout de disco da máquina local.
- **Não** habilitar Docker/DinD; apps serão Nix-native.
- **Não** dar sudo ao runner de CI.
- **Não** commitar segredos em texto plano; use sops.
- **Não** rodar `nixos-rebuild` sem `--flake` (o `/etc/nixos` está stale).
- **Não** expor a porta 3001 publicamente; use nginx/VPS.
- **Não** ativar comin antes de o commit com o próprio comin estar na `main` remota.
- **Não** ativar assinatura de commits antes de estabilizar o fluxo.
