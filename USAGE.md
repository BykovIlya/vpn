# Использование

## Команды

```bash
sudo bash client/add-device.sh name
sudo bash client/remove-device.sh name
sudo bash client/status.sh
sudo python3 manager/vpn_manager.py status
```

## На клиенте

1. Установить WireGuard
2. Импортировать конфиг
3. Активировать VPN

Проверка: `curl icanhazip.com` (должен быть IP сервера)
