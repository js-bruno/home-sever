#!/usr/bin/env bash
# setup-vps-wireguard-nginx.sh — VPS Debian/Ubuntu: WireGuard server + nginx
# proxy reverso para expor SOMENTE o Habbo/CMS (subdomínio hotel.<dominio>).
#
# Todo o resto (Netdata, Glance, Paperless, MySQL, Minecraft, SSH) fica
# restrito à LAN — o firewall do shatterdome bloqueia o túnel para essas
# portas (ver hosts/server/wireguard-vps.nix).
#
# O que este script cria na VPS:
#   1. WireGuard server (10.88.88.1/24) + par de chaves p/ o shatterdome
#   2. nginx HTTP -> http://10.88.88.2:80  (CMS/Habbo web)
#   3. nginx stream TCP 2096 -> 10.88.88.2:2096  (websocket do client Nitro)
#   4. HTTPS via Let's Encrypt (hotel.<dominio>)
#
# Uso (na VPS, com o script baixado — veja README):
#   sudo bash setup-vps-wireguard-nginx.sh <dominio> [sub]
# Exemplos:
#   sudo bash setup-vps-wireguard-nginx.sh thisdev.space hotel
#   sudo bash setup-vps-wireguard-nginx.sh thisdev.space habbo
#
# Pré-requisitos:
#   - Registro A de <sub>.<dominio> apontando pro IP da VPS
#     (ex.: registro.br / Cloudflare -> IP público da VPS)
#   - Portas 80, 443 e 51820/udp abertas no firewall da VPS (ufw/security group)
#   - No shatterdome: wireguard-vps.nix preenchido com as chaves impressas aqui

set -euo pipefail

DOMAIN="${1:?uso: $0 <dominio> [sub]}"
SUB="${2:-hotel}"

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
#    O client conecta em ws://<sub>.<dominio>:2096
#    IMPORTANTE: o bloco stream{} NÃO pode ficar em conf.d (lá é incluído
#    dentro de http{}). Usamos /etc/nginx/stream.d/ + include no nginx.conf.
#    O módulo no Debian é libnginx-mod-stream (nginx-extras é legado).
# ---------------------------------------------------------------------------
# O bloco stream{} NÃO pode ficar em conf.d (lá é incluído dentro de http{});
# e no main context (stream.d, top-level) `server` só é válido DENTRO de
# stream{} — SEMPRE com o wrapper. Execuções antigas gravavam em conf.d —
# remova, senão o nginx quebra o test. O restante do nginx.conf (blog,
# notes) não é tocado: só o include abaixo é adicionado.
apt-get install -y libnginx-mod-stream || echo "AVISO: falhou instalar libnginx-mod-stream"
rm -f /etc/nginx/conf.d/stream-habbo-ws.conf

mkdir -p /etc/nginx/stream.d
cat > /etc/nginx/stream.d/habbo-ws.conf <<EOF
stream {
    server {
        listen 2096;
        proxy_pass 10.88.88.2:2096;
        proxy_timeout 24h;
    }
}
EOF

# include top-level no nginx.conf (junto de http{}), sem duplicar
if ! grep -q "include /etc/nginx/stream.d/\*.conf;" /etc/nginx/nginx.conf; then
  sed -i '/^#\?.*http {/i include /etc/nginx/stream.d/*.conf;' /etc/nginx/nginx.conf
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