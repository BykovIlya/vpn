#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && log_error "Требуются права администратора"
[[ -z "${1:-}" ]] && log_error "sudo bash add-device.sh device_name"

DEVICE_NAME="$1"
[[ ! "$DEVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] && log_error "Неверное имя"

WG_CONFIG="/etc/wireguard/wg0.conf"
CLIENTS_DIR="/etc/wireguard/clients"
CREDS_FILE="/etc/wireguard/.credentials"

[[ ! -f "$WG_CONFIG" ]] && log_error "WireGuard не инициализирован"
source "$CREDS_FILE"

log_info "Генерирование ключей..."
DEVICE_PRIVKEY=$(wg genkey)
DEVICE_PUBKEY=$(echo "$DEVICE_PRIVKEY" | wg pubkey)

LAST_IP=$(grep -oP '10\.0\.0\.\K[0-9]+' "$WG_CONFIG" | sort -n | tail -1 || echo "1")
DEVICE_IP="10.0.0.$((LAST_IP + 1))"
[[ $((LAST_IP + 1)) -gt 254 ]] && log_error "IP исчерпаны"

log_success "IP: $DEVICE_IP"

cat >> "$WG_CONFIG" << EOF

# Device: $DEVICE_NAME
[Peer]
PublicKey = $DEVICE_PUBKEY
AllowedIPs = $DEVICE_IP/32
EOF

systemctl restart wg-quick@wg0

CLIENT_CONF="$CLIENTS_DIR/${DEVICE_NAME}.conf"
cat > "$CLIENT_CONF" << EOF
[Interface]
PrivateKey = $DEVICE_PRIVKEY
Address = $DEVICE_IP/24
DNS = 8.8.8.8, 1.1.1.1
MTU = 1420

[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $SERVER_IP:51820
PersistentKeepalive = 20
EOF

chmod 600 "$CLIENT_CONF"

command -v qrencode &> /dev/null && qrencode -t ansiutf8 < "$CLIENT_CONF"

echo "✅ Устройство добавлено!"
echo "Имя: $DEVICE_NAME"
echo "IP: $DEVICE_IP"
echo "Конфиг: $CLIENT_CONF"
