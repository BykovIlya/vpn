# Setup

> Single-folder layout: all scripts and docs can live in one directory on the server.

## Requirements
- Ubuntu 20.04+ / Debian 11+
- Root (sudo) access
- 1 GB RAM, 10 GB disk
- Public IP address

## 1) Copy files
Upload all files from this folder to the server (any directory).

Optionally create a `.env` next to the scripts (see `.env.example`).

## 2) Install WireGuard and configure server
```bash
sudo bash ./install.sh
```

This will:
- Install packages (wireguard, ufw, qrencode, etc.)
- Enable IP forwarding
- Create `/etc/wireguard/wg0.conf`
- Generate server keys and save them in `/etc/wireguard/.credentials`
- Start and enable the WireGuard interface
- Configure UFW to allow SSH and WireGuard UDP port

## 3) Add devices
```bash
sudo bash ./add-device.sh alice_phone
sudo bash ./add-device.sh alice_laptop
sudo bash ./add-device.sh bob_phone
```

## 4) Inspect status
```bash
sudo bash ./status.sh
sudo wg show wg0
```

## 5) Maintenance (optional)
```bash
sudo bash ./maintenance.sh
```

See `USAGE.md` and `TROUBLESHOOTING.md` for more.
