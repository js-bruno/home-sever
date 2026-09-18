# WireGuard cliente — túnel shatterdome -> VPS (proxy reverso público)
#
# A VPS (Debian/Ubuntu) roda o nginx + WireGuard server; os subdomínios
# públicos (netdata.<dominio>, glance.<dominio>, paperless.<dominio>) chegam
# pelo túnel 10.88.88.0/24 e são proxiados para os serviços locais.
#
# Gere as chaves com:
#   wg genkey | tee /tmp/wg0-priv | wg pubkey
# E edite PrivateKey + PreSharedKey + endpoint da VPS.

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

  # Firewall: permite o túnel criar conexões (saída), mas serviços locais
  # continuam fechados para a VPS por padrão — libere explicitamente abaixo
  # o que for público. O nginx da VPS se conecta a partir de 10.88.88.1.
  networking.firewall.allowedTCPPorts = [
    80 443               # vhosts locais (acesso LAN)
    8082                 # glance
    19999                # netdata
    28981                # paperless
    2096 3000            # habbo (game/ws)
  ];

  # Libera serviços para o túnel (VPS) — SÓ os públicos:
  networking.firewall.extraInputRules = ''
    ip saddr 10.88.88.1/32 tcp dport { 8082, 19999, 28981 } accept;
    ip saddr 10.88.88.1/32 udp dport 19999 accept;
    ip saddr 10.88.88.1/32 tcp dport 80 accept;   # CMS/Habbo se for público
  '';
}