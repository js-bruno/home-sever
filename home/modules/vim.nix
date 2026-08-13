{ ... }:
{
  programs.vim = {
    enable = true;
    defaultEditor = true;
    #plugins = with pkgs.vimPlugins; [ vim-airline ];
    extraConfig = builtins.readFile ../../dotfiles/vim/.vimrc;
  };
}
#environment.etc."vimrc".source = ./vimrc;
