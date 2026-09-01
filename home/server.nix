{ pkgs, ... }:
{
  imports = [
    ./modules/tmux.nix
  ];

  # extras específicos do servidor, se houver
  home.packages = with pkgs; [ 
    iw

    jdk17 #java
    maven

    php83
    php83Packages.composer

    nodejs_24
    yarn
  ];
}
