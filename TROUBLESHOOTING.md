# Troubleshooting

## Cannot connect
```bash
sudo systemctl status wg-quick@wg0
sudo ss -ulpn | grep 51820
sudo ufw status
sudo systemctl restart wg-quick@wg0
```

## Low disk space
```bash
df -h
sudo bash ./maintenance.sh
sudo journalctl --vacuum-time=1d
```

## DNS not working
Check client's DNS line in its config:
```bash
grep DNS /etc/wireguard/clients/<device>.conf
nslookup google.com
```
