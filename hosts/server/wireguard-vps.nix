# WireGuard cliente — túnel shatterdome -> VPS (somente Habbo/CMS público)
#
# A VPS (Debian/Ubuntu) roda nginx + WireGuard server. Único serviço exposto
# publicamente: o Habbo/CMS (via subdomínio habbo.<dominio> -> 10.88.88.2:80
# e o websocket do client em 10.88.88.2:2096, passado como TCP stream).
#
# Netdata, Glance, Paperless, MySQL, Minecraft e SSH continuam acessíveis SÓ
# pela LAN (192.168.15.0/24): o firewall local não deixa 10.88.88.1 (VPS)
# alcançá-los.
#
# Chaves (gere com: wg genkey | wg pubkey):
#   - PrivateKey do shatterdome -> arquivo /etc/wireguard/wg0.key (fora do store)
#   - publicKey da VPS          -> campo publicKey do peer abaixo
#   - PSK compartilhado         -> /etc/wireguard/wg0.psk
# O script setup-vps-wireguard-nginx.sh (mesma pasta) imprime as chaves na VPS.

{ config, pkgs, lib, ... }:
{
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.88.88.2/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/wg0.key"; # chave privada (fora do nix store)

    peers = [
      {
        # VPS (nginx + proxy reverso)
        publicKey = "VPS_PUBLIC_KEY_BASE64";
        presharedKeyFile = "/etc/wireguard/wg0.psk"; # opcional mas recomendado
        allowedIPs = [ "10.88.88.1/32" ]; # só o IP da VPS — não vaza tráfego
        endpoint = "SEU_IP_PUBLICO_DA_VPS:51820";
        persistentKeepalive = 25; # NAT/firewall da VPS não derrubar o túnel
      }
    ];
  };

  # Abertos para TODO mundo que chega ao servidor (LAN + túnel):
  #   80/443  -> CMS/Habbo web (o proxy da VPS e a LAN usam)
  #   2096    -> websocket do client Nitro (stream TCP na VPS + LAN)
  networking.firewall.allowedTCPPorts = [ 80 443 2096 ];

  # Resto dos serviços: SÓ LAN (192.168.15.0/24). A VPS (10.88.88.1) e a
  # internet não alcançam estas portas:
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.15.0/24 tcp dport { 3306, 8082, 19999, 28981, 3000, 3001, 25565, 2222 } accept;
  '';
}