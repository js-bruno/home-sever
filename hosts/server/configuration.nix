{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "server";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";

  users.users.gipsydanger = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # cole aqui sua chave pública SSH, ex:
      # "ssh-ed25519 AAAAC3Nza... voce@desktop"
    ];
  };

  programs.zsh.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Firewall básico
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # servidor não precisa de X/GUI
  services.xserver.enable = false;

  system.stateVersion = "24.05";
}
