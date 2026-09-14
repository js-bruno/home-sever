
{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "26.05";

  imports = [ ./modules ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  home.packages = with pkgs; [
    zoxide
    git
    wget
    curl
    dysk
    btop
    fastfetch
    lazygit
    tree
    ncdu
    iw
    opencode

    # DEV DEPENDENCIES
    jdk17 #java
    maven

    php83
    php83Packages.composer

    nodejs_24
    yarn
  ];

}
