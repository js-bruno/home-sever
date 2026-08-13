{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "26.05";

  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/vim.nix
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
