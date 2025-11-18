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

source /etc/os-release
[[ "$ID" != "ubuntu" && "$ID" != "debian" ]] && log_error "Только Ubuntu/Debian"

log_info "Установка пакетов..."
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq wireguard wireguard-tools linux-headers-"$(uname -r)" curl wget git ufw qrencode jq net-tools iptables-persistent

log_info "Kernel параметры..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p > /dev/null

log_info "WireGuard инициализация..."
mkdir -p /etc/wireguard/clients
chmod 700 /etc/wireguard
cd /etc/wireguard

SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)
SERVER_IP=$(curl -s https://checkip.amazonaws.com | xargs) || SERVER_IP="0.0.0.0"

cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.0.0.1/24
PrivateKey = SERVER_PRIVKEY_PLACEHOLDER
ListenPort = 51820
SaveCounter = true
DNS = 8.8.8.8, 1.1.1.1

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -A FORWARD -o wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -D FORWARD -o wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

sed -i "s|SERVER_PRIVKEY_PLACEHOLDER|$SERVER_PRIVKEY|g" /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0 > /dev/null 2>&1
systemctl start wg-quick@wg0

sleep 2
systemctl is-active --quiet wg-quick@wg0 || log_error "WireGuard не запустился"

cat > /etc/wireguard/.credentials << EOF
SERVER_PRIVKEY=$SERVER_PRIVKEY
SERVER_PUBKEY=$SERVER_PUBKEY
SERVER_IP=$SERVER_IP
EOF
chmod 600 /etc/wireguard/.credentials

log_info "Firewall..."
ufw --force reset > /dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment "SSH"
ufw allow 51820/udp comment "WireGuard"
echo "y" | ufw enable > /dev/null 2>&1

log_success "✅ VPN Server установлен!"
echo ""
echo "Public Key: $SERVER_PUBKEY"
echo "External IP: $SERVER_IP"
echo ""
echo "Добавьте устройства:"
echo "sudo bash client/add-device.sh device_name"
echo ""
