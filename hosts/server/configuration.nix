{ config, pkgs, lib, ... }:
{ 
  imports = [ 
    ./hardware-configuration.nix 
    ./network-local.nix 
    ./services
  ];

  programs.zsh.enable = true;
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  console.keyMap = "br-abnt2";

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
}
