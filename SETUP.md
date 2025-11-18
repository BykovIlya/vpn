# Установка

## Требования
- Ubuntu 20.04+ / Debian 11+
- 1GB+ RAM
- 10GB+ SSD
- Публичный IP

## Установка

```bash
git clone https://github.com/your-user/vpn-project.git
cd vpn-project
sudo bash server/install.sh
```

## Добавление устройств

```bash
sudo bash client/add-device.sh person1_phone
sudo bash client/add-device.sh person1_laptop
sudo bash client/add-device.sh person2_phone
sudo bash client/add-device.sh person2_laptop
sudo bash client/add-device.sh person2_tablet
```

## Проверка

```bash
sudo wg show wg0
sudo bash client/status.sh
```

Смотрите docs/USAGE.md и docs/TROUBLESHOOTING.md
