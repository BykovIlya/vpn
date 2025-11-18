# Проблемы

## Не подключается

```bash
sudo systemctl status wg-quick@wg0
sudo ss -ulpn | grep 51820
sudo ufw status
sudo systemctl restart wg-quick@wg0
```

## Мало места

```bash
df -h
sudo bash server/maintenance.sh
sudo journalctl --vacuum=1d
```

## DNS не работает

```bash
grep DNS /etc/wireguard/clients/device.conf
nslookup google.com
```
