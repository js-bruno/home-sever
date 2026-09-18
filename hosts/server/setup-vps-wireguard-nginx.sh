#!/usr/bin/env bash
# setup-vps-wireguard-nginx.sh — VPS Debian/Ubuntu: WireGuard server + nginx
# proxy reverso (HTTPS via Let's Encrypt) para serviços do shatterdome.
#
# Uso:
#   sudo bash setup-vps-wireguard-nginx.sh <dominio> <ip-publico-vps> [sub1 sub2 ...]
# Exemplo:
#   sudo bash setup-vps-wireguard-nginx.sh caravelho.com.br 203.0.113.10 netdata glance paperless
#
# Subdomínios criados: netdata.<dominio>, glance.<dominio>, paperless.<dominio> ...
# (web). O HOTEL pode ser exposto com o sub "habbo" (sem HTTPS, só HTTP, pois
# o client usa ws:// — veja a seção HABBO no final).
#
# Pré-requisitos:
#   - Domínio com registro A apontando para o IP público da VPS (já feito)
#   - Portas 80, 443 e 51820/udp abertas no firewall da VPS (ufw/security group)

set -euo pipefail

DOMAIN="${1:?uso: $0 <dominio> <ip-vps> [subdomains...]}"
VPS_IP="${2:?uso: $0 <dominio> <ip-vps> [subdomains...]}"
shift 2
SUBS=("$@")
[ ${#SUBS[@]} -gt 0 ] || SUBS=(netdata glance paperless)

# ---------------------------------------------------------------------------
# 1. WireGuard server
# ---------------------------------------------------------------------------
apt-get update -y
apt-get install -y wireguard nginx certbot python3-certbot-nginx curl

WG_DIR=/etc/wireguard
SERVER_PRIV="$WG_DIR/server_private.key"
SERVER_PUB="$WG_DIR/server_public.key"
SHATTER_PRIV="$WG_DIR/shatterdome_private.key"
SHATTER_PUB="$WG_DIR/shatterdome_public.key"

if [ ! -f "$SERVER_PRIV" ]; then
  umask 077
  wg genkey > "$SERVER_PRIV"
  wg pubkey < "$SERVER_PRIV" > "$SERVER_PUB"
  # Par de chaves PARA O SHATTERDOME (máquina NixOS). Copie estes arquivos
  # para ~/projects/nix-config? Não: os valores vão no wireguard-vps.nix.
  wg genkey > "$SHATTER_PRIV"
  wg pubkey < "$SHATTER_PRIV" > "$SHATTER_PUB"
  # PSK compartilhado (opcional mas recomendado)
  wg genpsk > "$WG_DIR/shared.psk"
fi

cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = 10.88.88.1/24
ListenPort = 51820
PrivateKey = $(cat "$SERVER_PRIV")
# Libera forwarding (o nginx da VPS alcança a LAN do servidor)
PostUp = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=0

[Peer]
# shatterdome (192.168.15.50)
PublicKey = $(cat "$SHATTER_PUB")
PresharedKey = $(cat "$WG_DIR/shared.psk")
AllowedIPs = 10.88.88.2/32
EOF

systemctl enable --now wg-quick@wg0
echo "== WireGuard server OK =="
echo "SERVER_PUBLIC_KEY=$(cat "$SERVER_PUB")"
echo "SHATTERDOME_PRIVATE_KEY=$(cat "$SHATTER_PRIV")"
echo "SHATTERDOME_PUBLIC_KEY=$(cat "$SHATTER_PUB")"
echo "PSK=$(cat "$WG_DIR/shared.psk")"
echo "-> Copie SHATTERDOME_PRIVATE_KEY e PSK para wireguard-vps.nix (PrivateKeyFile / presharedKeyFile)"
echo "-> e SERVER_PUBLIC_KEY em publicKey do peer."

# ---------------------------------------------------------------------------
# 2. nginx reverse proxy (vhosts por subdomínio)
# ---------------------------------------------------------------------------
for sub in "${SUBS[@]}"; do
  case "$sub" in
    netdata)  up="http://10.88.88.2:19999";;
    glance)   up="http://10.88.88.2:8082";;
    paperless) up="http://10.88.88.2:28981";;
    habbo)    up="http://10.88.88.2:80";;
    *)        echo "Subdomínio '$sub' desconhecido — pulei (use netdata/glance/paperless/habbo)"; continue;;
  esac

  cat > "/etc/nginx/sites-available/${sub}.${DOMAIN}" <<EOF
server {
    listen 80;
    server_name ${sub}.${DOMAIN};

    # Headers reais pro app (WebSocket para netdata)
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    location / {
        proxy_pass $up;
        proxy_redirect off;
    }
}
EOF
  ln -sf "/etc/nginx/sites-available/${sub}.${DOMAIN}" "/etc/nginx/sites-enabled/${sub}.${DOMAIN}"
done

# remove default site (evita conflito)
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl reload nginx

# ---------------------------------------------------------------------------
# 3. HTTPS (Let's Encrypt) para os subdomínios
# ---------------------------------------------------------------------------
for sub in "${SUBS[@]}"; do
  certbot --nginx -d "${sub}.${DOMAIN}" --non-interactive --agree-tos --redirect \
    -m "admin@${DOMAIN}" || echo "certbot falhou para ${sub}.${DOMAIN} (rede?)"
done

echo "== Pronto =="
echo "Acesse:"
for sub in "${SUBS[@]}"; do
  echo "  https://${sub}.${DOMAIN}"
done
echo
echo "== Se expuser o HABBO (sub 'habbo'): =="
echo "O client fala ws:// (porta 2096) — o nginx HTTP não proxia WebSocket TCP."
echo "Opções: a) só LAN; b) expor 2096 via TCP/UDP direto no roteador;"
echo "c) nginx stream{} na VPS:"
echo '  stream { server { listen 2096; proxy_pass 10.88.88.2:2096; } }'
echo "e o client usa ws://habbo.${DOMAIN}:2096 (HABBO-DEV-GUIDE: whitelist)."