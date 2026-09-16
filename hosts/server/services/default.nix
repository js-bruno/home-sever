{ ... }:
{
  imports = [
    ./ssh.nix
    ./mysql.nix
    ./habbo.nix
    ./nginx.nix
    ./minecraft.nix
    ./paperless.nix
    ./glance.nix
    ./netdata.nix
  ];
}

