{ pkgs, ... }:
{
  # pacotes/config que só fazem sentido numa máquina com GUI
  home.packages = with pkgs; [
    firefox
    vlc
    neovim
  ];
}
