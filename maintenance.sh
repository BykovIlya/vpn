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

journalctl --vacuum-time=1d || true
apt-get clean -qq || true
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
echo "[$(date)] Cleanup completed" >> /var/log/vpn-cleanup.log
ok "Maintenance tasks done."
