{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # se você já tem uma config própria (init.lua, lua/, etc),
  # coloque-a na pasta dotfiles/nvim deste repo e ela será
  # linkada automaticamente para ~/.config/nvim
  xdg.configFile."nvim" = {
    source = ../../dotfiles/nvim;
    recursive = true;
  };
}
