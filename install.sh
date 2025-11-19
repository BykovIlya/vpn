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

info "Detecting OS..."
source /etc/os-release || { error "Unsupported system: missing /etc/os-release"; exit 1; }
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  error "This installer supports Ubuntu/Debian only."; exit 1
fi

info "Installing packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq wireguard wireguard-tools linux-headers-"$(uname -r)" curl wget git ufw qrencode jq net-tools iptables-persistent

info "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
grep -q 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
grep -q 'net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p >/dev/null || true

info "Preparing directories..."
mkdir -p "$WG_CLIENTS_DIR"
chmod 700 "$WG_DIR"

cd "$WG_DIR"

info "Generating server keys..."
SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)

if [[ -z "$WG_ENDPOINT_IP" ]]; then
  info "Autodetecting external IP..."
  WG_ENDPOINT_IP=$(curl -s https://checkip.amazonaws.com || true)
  WG_ENDPOINT_IP=${WG_ENDPOINT_IP//$'\n'/}
  [[ -z "$WG_ENDPOINT_IP" ]] && { warn "Failed to autodetect external IP. You can set WG_ENDPOINT_IP in .env"; WG_ENDPOINT_IP="0.0.0.0"; }
fi

# Choose default egress interface (best effort)
EGRESS_IF=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' || echo "eth0")

cat > "$WG_DIR/wg0.conf" <<EOF
[Interface]
Address = ${WG_NETWORK%/*}.1/24
PrivateKey = ${SERVER_PRIVKEY}
ListenPort = ${WG_PORT}
SaveConfig = true
DNS = ${WG_DNS}

PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${EGRESS_IF} -j MASQUERADE; ip6tables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; ip6tables -A FORWARD -o ${WG_INTERFACE} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${EGRESS_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -D FORWARD -o ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${EGRESS_IF} -j MASQUERADE; ip6tables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; ip6tables -D FORWARD -o ${WGRESS_IF} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${EGRESS_IF} -j MASQUERADE
EOF

chmod 600 "$WG_DIR/wg0.conf"

# Persist env for other scripts (optional)
cp -f "${PWD}/.env" "$WG_DIR/.env" 2>/dev/null || true

cat > "$WG_DIR/.credentials" <<EOF
SERVER_PRIVKEY=${SERVER_PRIVKEY}
SERVER_PUBKEY=${SERVER_PUBKEY}
SERVER_IP=${WG_ENDPOINT_IP}
EOF
chmod 600 "$WG_DIR/.credentials"

info "Enabling service..."
systemctl enable wg-quick@"${WG_INTERFACE}" >/dev/null 2>&1 || true
systemctl restart wg-quick@"${WG_INTERFACE}" || { error "Failed to start WireGuard"; exit 1; }

info "Configuring firewall (ufw)..."
ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow ${ALLOW_SSH_PORT}/tcp comment "SSH"
ufw allow ${WG_PORT}/udp comment "WireGuard"
echo "y" | ufw enable >/dev/null 2>&1 || true

ok "VPN server installed successfully."
echo ""
echo "Public Key: ${SERVER_PUBKEY}"
echo "External IP: ${WG_ENDPOINT_IP}"
echo ""
echo "Add devices with:"
echo "  sudo bash ./add-device.sh <device_name>"
