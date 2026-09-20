# dnsmasq.nix — DNS local da LAN (shatterdome é o DNS dos clientes)
#
# Resolve os vhosts locais do proxy reverso para 192.168.15.50 e encaminha
# todo o resto para os resolvers upstream (1.1.1.1 / 8.8.8.8). Os clientes da
# LAN apontam o DNS para 192.168.15.50 e passam a resolver meudocs.com etc.

{ config, lib, ... }:
{
  services.dnsmasq = {
    enable = true;
    # Escuta na LAN e no loopback, com resolução local dos vhosts
    settings = {
      listen-address = "192.168.15.50,127.0.0.1";
      bind-interfaces = true;
      domain-needed = true;
      no-resolv = true; # usa o server= abaixo, não /etc/resolv.conf
      server = [ "1.1.1.1" "8.8.8.8" ];
      address = [
        "/meudocs.com/192.168.15.50"
        "/meuglance.com/192.168.15.50"
        "/meunetdata.com/192.168.15.50"
        "/meupaperless.com/192.168.15.50"
        "/meuexcalidraw.com/192.168.15.50"
      ];
    };
  };

  # Libera o DNS (53/udp+tcp) na LAN
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}