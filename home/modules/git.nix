{ ... }:
{
  programs.git = {
    enable = true;
    userName = "jsbruno";
    userEmail = "brunocebrsilva@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
