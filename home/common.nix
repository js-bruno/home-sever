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
  ];

}
