{ ... }:
{
  programs.git = {
    enable = true;
    userName = "seu-nome";
    userEmail = "seu-email@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
