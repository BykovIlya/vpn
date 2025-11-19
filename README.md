# VPN Project (Refactored)

A complete, production-grade **WireGuard VPN management toolkit** written in **Bash** and **Python**, refactored for clarity, security, and maintainability.  
All scripts and docs are self-contained — simply upload them to your server and run.

---

## 🚀 Features

- Automated WireGuard server installation (Ubuntu/Debian)
- Device (peer) management via Bash or Python CLI
- Environment configuration via `.env`
- Optional logging (console + file-based)
- QR code generation for mobile client setup
- Clean, English-language documentation and error handling
- Designed with best practices (`set -euo pipefail`, validation, structured logging)

---

## 🧰 Project Structure

```
.env.example
add-device.sh
remove-device.sh
install.sh
maintenance.sh
status.sh
vpn_manager.py
SETUP.md
USAGE.md
TROUBLESHOOTING.md
```

Each file is standalone. You can run Bash or Python commands directly from the same folder.

---

## ⚙️ Quick Start

### 1️⃣ Upload Files

Copy all files to your server (any directory). Example:
```bash
scp -r vpn_project_refactored user@server:/home/user/vpn/
```

### 2️⃣ Configure (optional)

Edit `.env` (copy from `.env.example`):
```bash
cp .env.example .env
nano .env
```

### 3️⃣ Install the VPN Server

```bash
sudo bash ./install.sh
```

This will:
- Install WireGuard, UFW, and dependencies
- Enable IP forwarding
- Generate server keys
- Configure `/etc/wireguard/wg0.conf`
- Start the VPN service

### 4️⃣ Add Devices

```bash
sudo bash ./add-device.sh phone
sudo bash ./add-device.sh laptop
```

Each device gets:
- Unique key pair
- Dedicated IP address
- Config file in `/etc/wireguard/clients/`
- Terminal QR code for easy mobile import

### 5️⃣ Check Status

```bash
sudo bash ./status.sh
```

---

## 🐍 Python Management CLI

If you prefer Python or want to integrate into automation:

```bash
sudo python3 ./vpn_manager.py --help
```

Examples:

```bash
sudo python3 ./vpn_manager.py status
sudo python3 ./vpn_manager.py list
sudo python3 ./vpn_manager.py add phone
sudo python3 ./vpn_manager.py remove phone
```

Use `--json` for machine-readable output, `-v` for verbose, and `--log-file` to enable persistent logging.

---

## 🔒 Environment Configuration (`.env`)

Key parameters you can override:

| Variable | Description | Default |
|-----------|-------------|----------|
| `WG_INTERFACE` | WireGuard interface name | `wg0` |
| `WG_PORT` | UDP listening port | `51820` |
| `WG_NETWORK` | Internal subnet | `10.0.0.0/24` |
| `WG_DNS` | DNS for clients | `8.8.8.8, 1.1.1.1` |
| `WG_DIR` | Server config directory | `/etc/wireguard` |
| `WG_CLIENTS_DIR` | Clients directory | `/etc/wireguard/clients` |
| `ALLOW_SSH_PORT` | Firewall SSH port | `22` |
| `LOG_FILE` | Optional log file path | *(disabled)* |

---

## 🧼 Maintenance

Clean up logs and temp files:
```bash
sudo bash ./maintenance.sh
```

---

## 🧩 Documentation

- **SETUP.md** — step-by-step installation guide
- **USAGE.md** — usage examples for Bash & Python
- **TROUBLESHOOTING.md** — common problems and fixes

---

## 🧠 Design Philosophy

This toolkit was refactored to follow senior-level engineering standards:
- Consistent validation and error handling
- Clear separation of concerns (server setup, device ops, monitoring)
- Minimal dependencies, portable scripts
- Human-readable output with optional structured logging
- `.env` configuration to decouple environment and code

---

## 🏁 License

MIT License — free to use and modify for personal or commercial projects.

---

## 👨‍💻 Author

Refactored professionally by a **Senior Python / DevOps Engineer** with focus on clarity, maintainability, and reliability.

---