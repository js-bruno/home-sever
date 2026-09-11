{ ... }:
{
  imports = [
    ./ssh.nix
    ./nginx.nix
    ./minecraft.nix
    ./paperless.nix
    ./glance.nix
    ./netdata.nix
  ];
}

