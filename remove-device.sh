#!/bin/bash
[[ $EUID -ne 0 ]] && echo "Need sudo" && exit 1
[[ -z "${1:-}" ]] && echo "sudo bash remove-device.sh device_name" && exit 1

sed -i "/# Device: $1/,/^$/d" /etc/wireguard/wg0.conf
systemctl restart wg-quick@wg0
rm -f "/etc/wireguard/clients/$1.conf"
echo "✓ Удалено: $1"
