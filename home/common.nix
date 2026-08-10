{ config, pkgs, ... }:
{
  home.stateVersion = "24.05";
  home.username = "seuusuario";
  home.homeDirectory = "/home/seuusuario";

  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/git.nix
  ];

  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    fzf
    tree
    htop
  ];

  # deixa o home-manager se gerenciar sozinho
  programs.home-manager.enable = true;
}
