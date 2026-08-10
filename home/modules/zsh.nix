{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = {
      ll = "ls -la";
      gs = "git status";
      gc = "git commit";
      ".." = "cd ..";
    };

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "sudo" "docker" ];
    };

    # cole aqui trechos do seu .zshrc atual que não tenham
    # opção declarativa direta
    initExtra = ''
      export EDITOR=nvim
      bindkey -e
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true; # isso te dá o comando "z"
  };
}
