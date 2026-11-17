#!/usr/bin/env bash
# setup-vps-forgejo.sh — VPS Debian/Ubuntu: vhost + HTTPS para a forge.
#
# A VPS já roda nginx + WireGuard (túnel para o shatterdome em 10.88.88.2).
# Este script NÃO mexe no vhost do hotel; só adiciona o da forge.
#
# Uso (na VPS):
#   sudo bash setup-vps-forgejo.sh thisdev.space git
#
# Pré-requisitos:
#   - registro A de <sub>.<dominio> apontando para o IP da VPS
#   - portas 80/443 abertas
#   - túnel WireGuard ativo (10.88.88.2:80 alcançável)
#
# Depois, no shatterdome, ajuste forgejo.nix:
#   ROOT_URL = "https://git.thisdev.space/"
#   COOKIE_SECURE = true

set -euo pipefail

DOMAIN="${1:-thisdev.space}"
SUB="${2:-git}"
SITE="/etc/nginx/sites-available/${SUB}.${DOMAIN}"

if [ "$(id -u)" -ne 0 ]; then
  echo "rode como root na VPS" >&2
  exit 1
fi

apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx

cat > "$SITE" <<EOF
server {
    listen 80;
    server_name ${SUB}.${DOMAIN};
    client_max_body_size 2g;

    location / {
        proxy_pass http://10.88.88.2:80;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

ln -sf "$SITE" "/etc/nginx/sites-enabled/${SUB}.${DOMAIN}"
nginx -t
systemctl reload nginx

certbot --nginx -d "${SUB}.${DOMAIN}" \
  --non-interactive --agree-tos --redirect \
  -m "admin@${DOMAIN}" || {
    echo "AVISO: certbot falhou; confira o DNS A de ${SUB}.${DOMAIN}" >&2
    exit 1
  }

echo "OK: https://${SUB}.${DOMAIN}"
echo "Agora ajuste ROOT_URL/COOKIE_SECURE no forgejo.nix do shatterdome."
