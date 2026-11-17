# AGENTS.md

Este repositório é a configuração NixOS do servidor `shatterdome`
(192.168.15.50). Antes de mudar qualquer coisa, leia o runbook completo:

- **`docs/agent-deploy.md`** — contexto, fases, comandos, troubleshooting e rollback.
- **`docs/network-fallback.md`** — watchdog do único link cabeado
  (`enp3s0`): restauração de endereço/rota e diagnóstico.

## Regras

- **Nunca** toque em `/dev/sda` (465 GB NTFS). O disco do NixOS é o `/dev/sdb2`
  (139 GB) definido em `hosts/server/hardware-configuration.nix`.
- **Não** reparticione, não mova `/nix`, não habilite Docker/DinD.
- **Não** rode `sudo` sem pedir ao usuário: `gipsydanger` não tem sudo sem senha.
  Prepare e valide; peça para o usuário rodar `sudo nixos-rebuild switch --flake .#server`.
- **Nunca** commite segredos em texto plano. Use sops (`hosts/server/secrets/`).
- Sempre use `--flake .#server`; o `/etc/nixos` está stale.
- Apps serão Nix-native (flake + `nixosModules`); OCI só para terceiros.
- Runner de CI **não** tem sudo; quem deploya é o comin.
- Grafana/Prometheus são **LAN-only**: não abra 3002/9090 globalmente.
- Loki/Alloy escutam só em loopback (3100/12345); não os exponha.

## Estado atual

Implementado:

- `hosts/server/services/forgejo.nix` — Forgejo LTS, SQLite, Actions, packages,
  nginx LAN direto em `http://192.168.15.50` e preparo para `git.thisdev.space`.
- `hosts/server/services/ci-runner.nix` — runner host mode, sem sudo, token
  manual em `/etc/forgejo-runner/token.env`.
- `hosts/server/services/comin.nix` — GitOps pull 30s, token manual em
  `/etc/comin/token`, branch `testing-server`, healthcheck.
- `hosts/server/services/sops.nix` — template, **não importado**.
- `hosts/server/services/observability.nix` — Prometheus 7d/2GB,
  node_exporter, Loki 7d, Alloy (journal -> Loki) e Grafana em
  `http://192.168.15.50:3002` (LAN-only).
- `hosts/server/services/net-fallback.nix` + `net-fallback.py` — watchdog
  do único link cabeado (`enp3s0`, IP fixo). Mantém a interface up, recria
  endereço/rota default após queda/retorno do cabo e testa internet de
  verdade no journal. Não há Wi-Fi nem segundo uplink: se cabo/ISP cair,
  não existe caminho alternativo; o serviço só restabelece quando o link
  volta.
- `hosts/server/services/grafana-dashboard.json` — dashboard provisionado
  (CPU, RAM, disco, load, Forgejo, comin e logs do Loki).
- `hosts/server/services/service-watch.py` — monitora Forgejo, comin, runner,
  Grafana, Prometheus, node_exporter, Loki, Alloy e o net-fallback
  (comin/runner ficam em falha até os tokens existirem).
- `flake.nix` — inputs `comin` e `sops-nix`; módulo do comin importado.
- `hosts/server/setup-vps-forgejo.sh` — vhost + certbot na VPS.
- `.forgejo/workflows/ci.yml` — eval em PR, build na main.
- `.sops.yaml` e `hosts/server/secrets/` — placeholders/modelo.

Falta criar (manual):

1. Admin do Forgejo e org `homelab`.
2. Repo `homelab/nix-config` migrado do GitHub.
3. Token read-only do comin → `/etc/comin/token`.
4. Token de registro do runner → `/etc/forgejo-runner/token.env`.
5. DNS `git.thisdev.space` → IP da VPS.
6. Rodar `setup-vps-forgejo.sh` na VPS e ajustar `ROOT_URL`/`COOKIE_SECURE`.
7. (Opcional) criar `hosts/server/secrets/server.yaml` cifrado, importar
   `sops.nix` e trocar os tokens manuais.

## Observabilidade

- Grafana: `http://192.168.15.50:3002` (LAN-only).
- Senha inicial do admin (gerada no primeiro boot):
  `sudo cat /var/lib/grafana/admin-password`.
- Prometheus e node_exporter escutam só em `127.0.0.1` (9090/9100).
- Loki escuta em `127.0.0.1:3100`, retenção de 7 dias em `/var/lib/loki`.
- Alloy lê o journal de Forgejo/comin/runner/nginx/Grafana/Prometheus e
  envia para o Loki (API local em `127.0.0.1:12345`).
- Forgejo expõe `/metrics` em `127.0.0.1:3001`; comin em `127.0.0.1:4243`.
- O dashboard `Shatterdome` é provisionado automaticamente, incluindo logs.

## Comandos de validação

```bash
nix flake show
nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link
# aplicação (pedir ao usuário):
sudo nixos-rebuild switch --flake .#server
```
