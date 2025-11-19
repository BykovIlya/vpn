#!/usr/bin/env bash
set -euo pipefail

# --- Helpers ---
info()    { echo -e "[INFO] $*"; }
ok()      { echo -e "[OK]   $*"; }
warn()    { echo -e "[WARN] $*"; }
error()   { echo -e "[ERR]  $*" >&2; }
need_root(){ if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then error "This script must be run as root (sudo)."; exit 1; fi; }

# Load .env if present (from current dir), else from /etc/wireguard if present
load_env() {
  local dotenv=".env"
  if [[ -f "$dotenv" ]]; then
    set -a; source "$dotenv"; set +a
  elif [[ -f "/etc/wireguard/.env" ]]; then
    set -a; source "/etc/wireguard/.env"; set +a
  fi
}

# Defaults (can be overridden by .env)
: "${WG_INTERFACE:=wg0}"
: "${WG_PORT:=51820}"
: "${WG_NETWORK:=10.0.0.0/24}"
: "${WG_DNS:=8.8.8.8, 1.1.1.1}"
: "${WG_ENDPOINT_IP:=}"
: "${WG_DIR:=/etc/wireguard}"
: "${WG_CLIENTS_DIR:=/etc/wireguard/clients}"
: "${ALLOW_SSH_PORT:=22}"

validate_device_name() {
  local name="${1:-}"
  [[ -z "$name" ]] && { error "Device name is required."; return 1; }
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || { error "Invalid device name. Allowed: letters, numbers, underscore, hyphen."; return 1; }
  return 0
}

need_root
load_env

NAME="${1:-}"
if ! validate_device_name "$NAME"; then
  echo "Usage: sudo bash ./add-device.sh <device_name>"
  exit 1
fi

WG_CONFIG="${WG_DIR}/wg0.conf"
CREDS_FILE="${WG_DIR}/.credentials"

[[ -f "$CREDS_FILE" ]] || { error "Missing credentials file: $CREDS_FILE"; exit 1; }
source "$CREDS_FILE"

[[ -f "$WG_CONFIG" ]] || { error "WireGuard not initialized. Missing $WG_CONFIG"; exit 1; }

info "Generating keys..."
DEVICE_PRIVKEY=$(wg genkey)
DEVICE_PUBKEY=$(echo "$DEVICE_PRIVKEY" | wg pubkey)

# Determine next IP (last octet)
LAST_IP=$(grep -oE 'Address *= *10\.0\.0\.[0-9]+' "$WG_CONFIG" | awk -F. '{print $4}' | sort -n | tail -1)
LAST_IP=${LAST_IP:-1}
NEXT=$((LAST_IP + 1))
if (( NEXT > 254 )); then
  error "IP pool exhausted in 10.0.0.0/24"; exit 1
fi
DEVICE_IP="10.0.0.${NEXT}"
ok "Assigned IP: ${DEVICE_IP}"

# Append peer
{
  echo ""
  echo "# Device: ${NAME}"
  echo "[Peer]"
  echo "PublicKey = ${DEVICE_PUBKEY}"
  echo "AllowedIPs = ${DEVICE_IP}/32"
} >> "$WG_CONFIG"

systemctl restart wg-quick@"${WG_INTERFACE}"

CLIENT_CONF="${WG_CLIENTS_DIR}/${NAME}.conf"
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = ${DEVICE_PRIVKEY}
Address = ${DEVICE_IP}/24
DNS = ${WG_DNS}
MTU = 1420

[Peer]
PublicKey = ${SERVER_PUBKEY}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${SERVER_IP}:${WG_PORT}
PersistentKeepalive = 20
EOF

chmod 600 "$CLIENT_CONF"

if command -v qrencode >/dev/null 2>&1; then
  echo
  echo "Scan this QR with your WireGuard mobile app:"
  qrencode -t ansiutf8 < "$CLIENT_CONF" || true
  echo
fi

ok "Device added."
echo "Name:   ${NAME}"
echo "IP:     ${DEVICE_IP}"
echo "Config: ${CLIENT_CONF}"
