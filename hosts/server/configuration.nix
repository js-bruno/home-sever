{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];
  nixpkgs.config.allowUnfree = true;

  networking = {
    hostName = "shatterdome";
    useDHCP = false;
    interfaces.enp2s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.15.50";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.15.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ 25565 2222 19999];
    networkmanager.enable = false;
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
    shell = pkgs.bash;

    #openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAAC3Nza... voce@desktop"
    #];
  };

  #programs.zsh.enable = true;

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
}
