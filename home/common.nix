{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "26.05";
  home.username = "gipsydanger";
  home.homeDirectory = "/home/gipsydanger";

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
    ncdu
  ];

}
