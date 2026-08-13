{ pkgs, ... }:
{
  programs.neovim = {
    enable = false;
    defaultEditor = false;
    viAlias = false;
    vimAlias = false;
  };

  # se você já tem uma config própria (init.lua, lua/, etc),
  # coloque-a na pasta dotfiles/nvim deste repo e ela será
  # linkada automaticamente para ~/.config/nvim
  xdg.configFile."nvim" = {
    source = ../../dotfiles/nvim;
    recursive = true;
  };
}
