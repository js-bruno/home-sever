{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      AllowUsers = [ "gipsydanger" ];
    };
    ports = [ 2222 ];
  };
  networking.firewall.allowedTCPPorts = [ 2222 ];
}
