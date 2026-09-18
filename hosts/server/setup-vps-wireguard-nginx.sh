#!/usr/bin/env bash
# setup-vps-wireguard-nginx.sh — VPS Debian/Ubuntu: WireGuard server + nginx
# proxy reverso para expor SOMENTE o Habbo/CMS (subdomínio habbo.<dominio>).
#
# Todo o resto (Netdata, Glance, Paperless, MySQL, Minecraft, SSH) fica
# restrito à LAN — o firewall do shatterdome bloqueia o túnel para essas
# portas (ver hosts/server/wireguard-vps.nix).
#
# O que este script cria na VPS:
#   1. WireGuard server (10.88.88.1/24) + par de chaves p/ o shatterdome
#   2. nginx HTTP -> http://10.88.88.2:80  (CMS/Habbo web)
#   3. nginx stream TCP 2096 -> 10.88.88.2:2096  (websocket do client Nitro)
#   4. HTTPS via Let's Encrypt (habbo.<dominio>)
#
# Uso (na VPS, com o script baixado — veja README):
#   sudo bash setup-vps-wireguard-nginx.sh <dominio>
# Exemplo:
#   sudo bash setup-vps-wireguard-nginx.sh caravelho.com.br
#
# Pré-requisitos:
#   - Registro A de <dominio> e habbo.<dominio> apontando pro IP da VPS
#     (ex.: registro.br / Cloudflare -> IP público da VPS)
#   - Portas 80, 443 e 51820/udp abertas no firewall da VPS (ufw/security group)
#   - No shatterdome: wireguard-vps.nix preenchido com as chaves impressas aqui

set -euo pipefail

DOMAIN="${1:?uso: $0 <dominio>}"
SUB="habbo"

# ---------------------------------------------------------------------------
# 1. WireGuard server
# ---------------------------------------------------------------------------
apt-get update -y
apt-get install -y wireguard nginx certbot python3-certbot-nginx

WG_DIR=/etc/wireguard
SERVER_PRIV="$WG_DIR/server_private.key"
SERVER_PUB="$WG_DIR/server_public.key"
SHATTER_PRIV="$WG_DIR/shatterdome_private.key"
SHATTER_PUB="$WG_DIR/shatterdome_public.key"

if [ ! -f "$SERVER_PRIV" ]; then
  umask 077
  wg genkey > "$SERVER_PRIV"
  wg pubkey < "$SERVER_PRIV" > "$SERVER_PUB"
  wg genkey > "$SHATTER_PRIV"
  wg pubkey < "$SHATTER_PRIV" > "$SHATTER_PUB"
  wg genpsk > "$WG_DIR/shared.psk"
fi

cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = 10.88.88.1/24
ListenPort = 51820
PrivateKey = $(cat "$SERVER_PRIV")

[Peer]
# shatterdome (192.168.15.50) — único peer
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
echo "-> No shatterdome: edite hosts/server/wireguard-vps.nix com esses valores"
echo "   (publicKey = SERVER_PUBLIC_KEY; PrivateKey/PSK em /etc/wireguard/*)"

# ---------------------------------------------------------------------------
# 2. nginx HTTP -> CMS (10.88.88.2:80)
# ---------------------------------------------------------------------------
cat > "/etc/nginx/sites-available/${SUB}.${DOMAIN}" <<EOF
server {
    listen 80;
    server_name ${SUB}.${DOMAIN};

    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    location / {
        proxy_pass http://10.88.88.2:80;
        proxy_redirect off;
    }
}
EOF
ln -sf "/etc/nginx/sites-available/${SUB}.${DOMAIN}" "/etc/nginx/sites-enabled/${SUB}.${DOMAIN}"
rm -f /etc/nginx/sites-enabled/default

# ---------------------------------------------------------------------------
# 3. nginx stream TCP 2096 -> websocket Nitro (10.88.88.2:2096)
#    O client conecta em ws://habbo.<dominio>:2096
# ---------------------------------------------------------------------------
cat > /etc/nginx/conf.d/stream-habbo-ws.conf <<EOF
stream {
    server {
        listen 2096;
        proxy_pass 10.88.88.2:2096;
        proxy_timeout 24h;
    }
}
EOF
# stream{} precisa do módulo stream carregado
if ! nginx -t 2>&1 | grep -q "unknown directive \"stream\""; then
  : # ok, module presente
else
  # Debian/Ubuntu: o nginx padrão traz stream; se não, instala nginx-extras
  apt-get install -y nginx-extras || echo "AVISO: nginx sem módulo stream — ws 2096 não vai expor"
fi

nginx -t
systemctl enable --now nginx
systemctl reload nginx

# ---------------------------------------------------------------------------
# 4. HTTPS (Let's Encrypt) — habbo.<dominio>
# ---------------------------------------------------------------------------
certbot --nginx -d "${SUB}.${DOMAIN}" --non-interactive --agree-tos --redirect \
  -m "admin@${DOMAIN}" || echo "certbot falhou para ${SUB}.${DOMAIN} (rede? verifique o registro A)"

echo
echo "== Pronto =="
echo "  Web:     https://${SUB}.${DOMAIN}"
echo "  Websocket: ws://${SUB}.${DOMAIN}:2096  (usado pelo client Nitro)"
echo
echo "RELEMBRE no shatterdome (nginx local do CMS):"
echo "  1. sub_filter do renderer-config.json já troca ws://localhost por \$host"
echo "  2. websockets.whitelist do plugin precisa incluir ${SUB}.${DOMAIN}"
echo "  3. Habilitar enc.enabled? Não — só se o client exigir TLS no ws."