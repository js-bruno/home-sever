{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "24.05";
  home.username = "seuusuario";
  home.homeDirectory = "/home/seuusuario";

  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/git.nix
  ];

  home.packages = with pkgs; [
    git
    wget
    curl
    dysk
    btop
    fastfetch
    tree
  ];

}
