{ ... }:
{
  networking = {
    hostName = "shatterdome";
    useDHCP = false;
    interfaces.enp3s0 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.15.50";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.15.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    firewall.allowedTCPPorts = [ 8082 80 443 2096 3001 3306 25565 2222 19999 28981];
    networkmanager.enable = false;
    wireless = {
      enable = true;
      interfaces = [ "wlp2s0" ];
    };
  };


}

