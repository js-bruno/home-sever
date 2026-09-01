# nix-config

Configuração NixOS + home-manager para desktop e servidor, com módulos
reutilizáveis (zsh, neovim, git, tmux).

## Estrutura

```
.
├── flake.nix
├── hosts/
│   ├── desktop/configuration.nix
│   └── server/configuration.nix
├── home/
│   ├── common.nix       # importado nos dois hosts
│   ├── desktop.nix       # extras só do desktop
│   ├── server.nix         # extras só do server (tmux)
│   └── modules/
│       ├── zsh.nix
│       ├── neovim.nix
│       ├── git.nix
│       └── tmux.nix
└── dotfiles/
    └── nvim/              # sua config de neovim (init.lua, lua/, etc)
```

## Antes de usar

1. Troque `seuusuario`, `seu-nome` e `seu-email@example.com` em:
   - `flake.nix`
   - `hosts/desktop/configuration.nix`
   - `hosts/server/configuration.nix`
   - `home/common.nix`
   - `home/modules/git.nix`
2. Cole sua chave pública SSH em
   `hosts/server/configuration.nix` (`openssh.authorizedKeys.keys`).
3. Gere o `hardware-configuration.nix` real de cada máquina:

   ```bash
   sudo nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix
   sudo nixos-generate-config --show-hardware-config > hosts/server/hardware-configuration.nix
   ```

   (rode cada comando na máquina correspondente e substitua o
   placeholder que já está no repo)

4. Se já tiver uma config de neovim, jogue o conteúdo dentro de
   `dotfiles/nvim/` (substituindo o `init.lua` placeholder).

## Aplicando

No desktop:

```bash
sudo nixos-rebuild switch --flake .#desktop
```

No servidor (via SSH, dentro do repo):

```bash
sudo nixos-rebuild switch --flake .#server
```

Deploy remoto direto do desktop (sem entrar no servidor):

```bash
sudo nixos-rebuild switch --flake .#server --target-host root@IP-DO-SERVIDOR
```

## Adicionando uma máquina nova

```bash
git clone <seu-repo> ~/nix-config
cd ~/nix-config
sudo nixos-generate-config --show-hardware-config > hosts/nova-maquina/hardware-configuration.nix
# crie hosts/nova-maquina/configuration.nix (copie de outro host e ajuste)
# adicione "nova-maquina" em flake.nix, igual desktop/server
sudo nixos-rebuild switch --flake .#nova-maquina
```

[ Navegador do Usuário (Cliente) ]
       │                   │
       │ (1) HTTP/HTTPS    │ (4) WebSocket (ws://)
       │                   │
       ▼                   ▼
+---------------------------------------------------+
|                      NGINX                        |
| - Serve Nitro Client (HTML/JS) e Assets (Imagens) |
| - Proxy reverso para o WebSocket (Opcional)       |
+---------------------------------------------------+
       │
       │ (2) FastCGI
       ▼
+-----------------------+       +------------------------------------+
|     CMS (PHP-FPM)     |       |         Arcturus Emulator          |
| - Portal de login     |       | - Servidor backend em Java         |
| - Gera o SSO Ticket   |       | - Gerencia o jogo e conexões TCP   |
+-----------------------+       +------------------------------------+
       │                                           │
       │ (3) Leitura/Escrita PDO                   │ (5) Conexão JDBC
       ▼                                           ▼
+---------------------------------------------------+
|               MariaDB (Porta 3306)                |
| - Armazena usuários, quartos, tokens SSO          |
| - Contém a tabela emulator_settings               |
+---------------------------------------------------+
