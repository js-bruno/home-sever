{ ... }:
{
  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile ../../dotfiles/vim/.vimrc;
  };
}
#environment.etc."vimrc".source = ./vimrc;
