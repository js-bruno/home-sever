{ pkgs, ... }:
{
  imports = [
    ./modules/tmux.nix
  ];

  # extras específicos do servidor, se houver
  home.packages = with pkgs; [ ];
}
