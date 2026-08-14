{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home.stateVersion = "26.05";

  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/vim.nix
    ./modules/git.nix
    ./modules/minecraft_forge_server.nix
  ];

  home.packages = with pkgs; [
    git
    wget
    curl
    dysk
    btop
    fastfetch
    lazygit
    tree
    ncdu
  ];

}
