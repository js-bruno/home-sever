# minecraft-server.nix

#
# Como usar:
#   1. Adicione ao seu flake.nix (veja flake-example.nix)
#   2. Execute: nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <VERSION_ID>
#      para cada mod e substitua os hashes marcados com "HASH_PENDENTE"
#   3. Execute: sudo nixos-rebuild switch
#
# Para conectar ao console do servidor:
#   tmux -S /run/minecraft/survival.sock attach
#   (Ctrl+b, d para desconectar)

{ inputs, pkgs, lib, ... }:

let
  # ─── Utilitário para buscar mods do Modrinth ────────────────────────────────
  # Uso: modrinthMod { versionId = "ABC123"; url = "https://cdn.modrinth.com/..."; sha512 = "..."; }
  modrinthMod = { url, sha512, ... }:
    pkgs.fetchurl {
      inherit url sha512;
    };

  # ─── MODS DE PERFORMANCE ────────────────────────────────────────────────────
  # Todos compatíveis com NeoForge 1.21.4 (server-side)
  #
  # Para obter os hashes corretos, rode:
  #   nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- <VERSION_ID>

  # VERSION_IDs para buscar:
  #   FerriteCore 7.1.2   → joOID027
  #   ModernFix 5.20.3    → xbg7UvQT   (build neoforge)
  #   ServerCore 1.5.4    → vCnDCHyg
  #   Clumps 24.0.0.4     → 2zQSp93Z
  #   Waystones 21.4.0    → fuEeXjq1
  #   JEI 19.21.0.247     → V5vS77Gp
  #   JEI 19.21.0.247     → ilGj0jiA
  # balm -> 1C3tVoOk
  # collective -> I5jY2gQ2

  #   nix run github:Infinidoge/nix-minecraft#nix-modrinth-prefetch -- I5jY2gQ2

ferriteCore = modrinthMod { 
  url = "https://cdn.modrinth.com/data/uXXizFIs/versions/joOID027/ferritecore-7.1.3-neoforge.jar";
  sha512 = "c66509657387327f0a7652f3f2ba57a0deb96a96a9ea744bae0ca38f84ca550f43d189bcfbf3919c1f5109665b092790026c140f93156cb5ad7f9f1f34476774"; 
};

modernFix = modrinthMod {
  url = "https://cdn.modrinth.com/data/nmDcB62a/versions/xbg7UvQT/modernfix-neoforge-5.20.3%2Bmc1.21.4.jar";
  sha512 = "3d1bbd2b9d63fa78da2df10c32d4e04b17781b6570faaedaf849761c764ea7f41c34b6df1f58300efa66111712f3cda79966c98673b58a65a8d4b03912dbf045"; 
};

serverCore = modrinthMod { 
  url = "https://cdn.modrinth.com/data/4WWQxlQP/versions/vCnDCHyg/servercore-neoforge-1.5.8%2B1.21.4.jar";
  sha512 = "84f729168516aa9182498fedd61efa7cb1f3beb7bfb1d4ffab063e6212686bc6fb7aaa0fdb0933be674ada11c77342f3d747f2ccab8f7d3c9c422c49aef30592"; 
};

clumps = modrinthMod { 
  url = "https://cdn.modrinth.com/data/Wnxd13zP/versions/2zQSp93Z/Clumps-neoforge-1.21.4-22.0.0.1.jar";
  sha512 = "63b04f1292fe5ea025fc7b6eb1e357019d4f77e76fbaef22bb2ca74f9df30634428f3e60ae06ed1fe3f82dcb49d286a68739d049326e1a475d0817c14b6373cb"; 
};


  # ─── MODS DE SURVIVAL / QUALIDADE DE VIDA ───────────────────────────────────
waystones = modrinthMod {
  url = "https://cdn.modrinth.com/data/LOpKHB2A/versions/fuEeXjq1/waystones-neoforge-1.21.4-21.4.19.jar";
  sha512 = "fb90ed2d4e7a5ef0c6bf61560b5d130cdcf817622aa1bd6a7f36cd7ee29b206c7e627a118dc052dc52e1cf07e0c124b7e6e0e9d9f96d721658e4657f27deae31";
};

balm = modrinthMod { 
  url = "https://cdn.modrinth.com/data/MBAkmtvl/versions/1C3tVoOk/balm-neoforge-1.21.4-21.4.42.jar";
  sha512 = "a32f249e33162784910d09a52e0ccd7a971326e27762adf1a2085332a4d020e4e0807d7fd2e535c6c4cb7fb88c800eeab6371b0dd5b1b1fc427c7694d359ac8a"; 
};

jei = modrinthMod { 
  url = "https://cdn.modrinth.com/data/u6dRKJwZ/versions/V5vS77Gp/jei-1.21.4-neoforge-20.0.0.4.jar";
  sha512 = "24da2899b14909fc727980a866400b66cda9f404452d91151bdea88e947a2a3bce837c626121d8fb894a83d35b8ffcb5cff0d93f21143c12044155b495993043";
};


treeHarvester = modrinthMod {
  url = "https://cdn.modrinth.com/data/abooMhox/versions/ilGj0jiA/treeharvester-1.21.4-9.1.jar";
  sha512 = "aeaa9c1ddb93f1cf240f5b1dfe8fc937806589f1d8b95d5193b81b7e2f7e4dcd0ae509e4cfbea75ae8f6b2b4edf43c286b3523acd8d0af3b009af4b45588cdd0"; 
};

collective = modrinthMod {
 url = "https://cdn.modrinth.com/data/e0M1UDsY/versions/I5jY2gQ2/collective-1.21.4-8.3.jar";
 sha512 = "95c18b55a631bfdcbc501c17238f36c1f284d90a866f498dbf2b77ce7b9dcb0260cba0143a16dcbf254660710ea8fdbd8948cac94139e660bf25581b49fa2337";
};

in
{
  # ─── IMPORTAR MÓDULO DO NIX-MINECRAFT ───────────────────────────────────────
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];

  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  # ─── CONFIGURAÇÃO DO SERVIDOR ────────────────────────────────────────────────
  services.minecraft-servers = {
    enable      = true;
    eula        = true;        # Você concorda com a EULA da Mojang
    openFirewall = true;       # Abre porta 25565 no firewall

    servers.survival = {
      enable    = true;
      autoStart = true;

      # NeoForge 1.21.4 (usa a versão mais recente disponível no nix-minecraft)
      # Para ver versões disponíveis: nix eval github:Infinidoge/nix-minecraft#legacyPackages.x86_64-linux.neoforgeServers --apply builtins.attrNames
      package = pkgs.neoforgeServers.neoforge-1_21_4;

      # ─── JVM OPTIONS ──────────────────────────────────────────────────────
      # Ajuste -Xms e -Xmx conforme sua RAM disponível:
      #   4GB  RAM: "-Xms2G -Xmx3G"
      #   8GB  RAM: "-Xms4G -Xmx6G"
      #   16GB RAM: "-Xms6G -Xmx12G"
      jvmOpts = lib.concatStringsSep " " [
        "-Xms4G"
        "-Xmx4G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
        "-Dusing.aikars.flags=https://mcflags.emc.gs"
        "-Daikars.new.flags=true"
      ];

      # ─── SERVER PROPERTIES ────────────────────────────────────────────────
      serverProperties = {
        # Rede
        server-ip =             "0.0.0.0";  
        server-port              = 25565;
        online-mode              = false;    # false para servidor offline/pirata

        # Gameplay
        difficulty               = "normal";
        gamemode                 = "survival";
        max-players              = 20;
        spawn-protection         = 16;
        allow-nether             = true;
        allow-flight             = false;

        # Mundo
        level-name               = "world";
        level-type               = "minecraft:default";
        view-distance            = 15;
        simulation-distance      = 12;
        # seed                   = "";   # Descomente e defina uma seed se quiser

        # Mensagem do servidor (MOTD)
        motd                     = "\\u00A76\\u00A7lMeu Servidor NixOS \\u00A7r\\u00A77| NeoForge 1.21.4";

        # Performance
        max-tick-time            = 60000;
        network-compression-threshold = 256;
        sync-chunk-writes        = false;  # async writes = menos lag de I/O
        use-native-transport     = true;

        # Whitelist (defina true para só permitir jogadores listados abaixo)
        white-list               = false;

        # RCON (admin remoto) — opcional
        enable-rcon              = false;
        # "rcon.port"            = 25575;
        # "rcon.password"        = "TROQUE_ESTA_SENHA";  # use sops-nix ou agenix para secrets!
      };

      # ─── OPERADORES ───────────────────────────────────────────────────────
      # Adicione seu UUID de jogador aqui
      # Para encontrar o UUID: https://api.mojang.com/users/profiles/minecraft/<seuNick>
      operators = {
        # SeuNick = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
      };

      # ─── WHITELIST (somente se white-list = true) ─────────────────────────
      # whitelist = {
      #   SeuNick = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
      # };

      # ─── MODS ─────────────────────────────────────────────────────────────
      symlinks = {
        # Cria pasta mods/ com symlinks para os JARs no Nix store
        "mods" = pkgs.linkFarmFromDrvs "mods" [
          ferriteCore    # Redução de RAM — essencial para NeoForge
          modernFix      # Startup mais rápido + correções de bugs
          serverCore     # Otimização de TPS, mob caps dinâmicos
          clumps         # Agrupa XP orbs → menos lag em farms
          waystones      # Fast travel declarativo
          jei            # Recipe browser (funciona server-side para sync)
          balm
          collective
          treeHarvester
        ];
      };

      # ─── CONFIGURAÇÕES DOS MODS ───────────────────────────────────────────
      files = {
        # Exemplo: configuração do ServerCore
        "config/servercore.toml".value = {
          performance = {
            # Distância mínima de simulação sob lag
            min_simulation_distance    = 4;
            # Reduz mob caps quando TPS cai abaixo de 18
            dynamic_mob_caps           = true;
            dynamic_mob_caps_threshold = 18.0;
          };
        };

        # Exemplo: configuração do ModernFix
        "config/modernfix-common.toml".value = {
          mixin = {
            perf = {
              # Habilita carregamento dinâmico de modelos (economiza muita RAM)
              dynamic_resources = { enabled = true; };
            };
          };
        };
      };

      # ─── RELOAD SEM RESTART ───────────────────────────────────────────────
      # Quando você faz nixos-rebuild switch, o servidor reinicia symlinks
      # sem precisar dar stop/start completo
      enableReload = true;
    };
  };

  # ─── GRUPO DO SERVIDOR ────────────────────────────────────────────────────
  # Adicione seu usuário ao grupo para poder acessar o tmux socket
  # users.users.SeuUsuario.extraGroups = [ "minecraft" ];
}
