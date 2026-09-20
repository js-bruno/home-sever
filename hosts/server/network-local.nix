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
    firewall.allowedTCPPorts = [ 80 443 25565 2222 2096 3000 3306 ];
    networkmanager.enable = false;
    wireless = {
      enable = true;
      interfaces = [ "wlp2s0" ];
    };
  };


}

