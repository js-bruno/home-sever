{ config, pkgs, lib, ... }: { imports = [
./hardware-configuration.nix ];
  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;

  networking = {
    hostName = "shatterdome";
    useDHCP = false;
    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.15.50";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.15.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ 80 443 2096 3306 25565 2222 19999];
    networkmanager.enable = false;
    wireless = {
      enable = true;
      interfaces = [ "wlp2s0" ];
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # enable textmode when initializes
  # run `sudo systemctl start display-manager` to start interfaces
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  time.timeZone = "America/Fortaleza";
  i18n.defaultLocale = "pt_BR.UTF-8";

  users.users.gipsydanger = {
    isNormalUser = true;
    description = "Only user in this machine";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;

    #openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAAC3Nza... voce@desktop"
    #];
  };


  services.mysql = {
    package = pkgs.mariadb;
    enable = true;
    ensureDatabases = ["habbo"];
    ensureUsers = [{
      name = "habbo";
      ensurePermissions = { "habbo.*" = "ALL PRIVILEGES"; };
    }];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "gipsydanger" ];
    };
    ports = [ 2222 ];
  };

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.mate.enable = true;
  services.xserver.xkb = {
    layout = "br";
    variant = "";
  };

  services.fail2ban.enable = true;
  services.netdata.enable = true;
  services.printing.enable = true;

  console.keyMap = "br-abnt2";
  system.stateVersion = "26.05";

  services.phpfpm.pools.habbo = {
    user = "nginx";
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = "5";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
    };
  };
  
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."caravelho.com.br" = { # Substitua "_" pelo seu domínio se houver
    root = "/var/www/habbo/public"; # Raiz pública da CMS

    locations."/" = {
      index = "index.php index.html";
      tryFiles = "$uri $uri/ /index.php?$query_string";
    };

    locations."~ \\.php$" = {
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.habbo.socket};
        fastcgi_index index.php;
        include ${pkgs.nginx}/conf/fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
      '';
    };
    };
  };
}
