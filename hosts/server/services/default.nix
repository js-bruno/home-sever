# services/default.nix — serviços deste host (shatterdome)
#
# O stack Habbo (emulador + CMS + nginx + mysql) vem do módulo externo
# habbo-nixos (ver flake.nix → nixosModules.habbo). Aqui ficam só os serviços
# específicos do host que não fazem parte do módulo.

{ inputs, ... }:
{
  imports = [
    ./ssh.nix
    ./minecraft.nix
    ./paperless.nix
    ./glance.nix
    ./netdata.nix
    ./hotel-vhost.nix
    ./docs-vhost.nix
  ];
}