# Usage

## Bash helpers

Add a device:
```bash
sudo bash ./add-device.sh <device_name>
```

Remove a device:
```bash
sudo bash ./remove-device.sh <device_name>
```

Show status:
```bash
sudo bash ./status.sh
```

## Python CLI (optional, requires python3 and optionally python-dotenv)
```bash
sudo python3 ./vpn_manager.py --help
sudo python3 ./vpn_manager.py status
sudo python3 ./vpn_manager.py list
sudo python3 ./vpn_manager.py add <device_name>
sudo python3 ./vpn_manager.py remove <device_name>
```

### JSON output for integrations
```bash
sudo python3 ./vpn_manager.py --json status
```

### Logging to a file (optional)
Set `LOG_FILE=/var/log/vpn_manager.log` in `.env` (or pass `--log-file`), then:
```bash
sudo python3 ./vpn_manager.py -v status
```

## Client setup
1. Install WireGuard on the device.
2. Copy the generated `.conf` from `/etc/wireguard/clients/<device>.conf` **or** scan the QR shown after `add-device.sh`.
3. Activate the tunnel.
4. Verify:
```bash
curl icanhazip.com   # should return server's public IP
```
