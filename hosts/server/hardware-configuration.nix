# ATENÇÃO: este arquivo é só um placeholder.
# Gere o de verdade na máquina com:
#   sudo nixos-generate-config --show-hardware-config > hosts/server/hardware-configuration.nix
# e substitua este conteúdo.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # boot.initrd.availableKernelModules, fileSystems, swapDevices, etc
  # serão preenchidos automaticamente pelo nixos-generate-config.
}
