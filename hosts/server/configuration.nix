# nix-config — configuração do servidor gipsydanger (shatterdome)
#
# O stack Habbo Retro (Arcturus + Atom CMS + Nitro) é declarado pelo flake
# externo habbo-nixos (github:js-bruno/habbo-retro-nix), importado via
# nixosModules.habbo (ver ./flake.nix). Isso inclui: services.mysql (bancos
# habbo+orioncms), habbo-arcturus.service, phpfpm pool 'habbo' com
# ProtectHome=false, nginx vhost caravelho.com.br com /client/ + sub_filter,
# usuário 'habbo' e firewall. O que resta aqui é específico deste host.

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
    homeMode = "755";
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
}