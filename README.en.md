Like the project? Support the author via [CloudTips](https://pay.cloudtips.ru/p/8ec8a87c) or [Yoomoney](https://yoomoney.ru/to/41001945296522) for a cup of coffee ☕ 

***

# Installation for Debian 10-12 or Ubuntu 20.04-24.04

## About MTProxy
**MTProxy** is an official Telegram proxy server based on MTProto for accessing Telegram in regions with network restrictions.  
The official repository [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) is outdated and has compilation issues, so this installation script resolves those with improvements.

## Main Script Features

- Installs, reinstalls, or completely removes MTProxy.
- Allows selection of external and internal ports during installation/reinstallation.
- Sets up automatic daily configuration updates via `cron` for stable proxy operation.
- Updates MTProxy secret with a single command.
- Generates connection links after installation.

## System Requirements

- **OS**: Debian 10, 11, 12 or Ubuntu 20.04, 22.04, 22.10, 23.04, 24.04
- **RAM**: 512 MB or more
- **CPU**: 1 core or more
- **Disk**: 1 GB
- **Network**: Static public IP

## Installation Instructions

Run the following commands in the terminal:

```
# Download the script
wget -O install_mtproxy_english.sh https://raw.githubusercontent.com/Internet-Helper/MTProto-MTProxy-Telegram/refs/heads/main/install_mtproxy_english.sh

# Grant execution permissions
chmod +x install_mtproxy_english.sh

# Run the script
sudo ./install_mtproxy_english.sh
```

After updating and installing required packages, the script will prompt you to select external and internal ports:

![image](https://github.com/user-attachments/assets/83ebe224-efcb-4d54-8424-431cb5e5c96d)

## Setup and Usage

After launching **MTProxy**, you will receive the following details:

![image](https://github.com/user-attachments/assets/d1c6d77a-9f14-4190-83ef-1b22f493b3e4)

## Proxy Setup Instructions:

For **`https://t.me/proxy?server=...`**:
1. Click the link or share it in any chat
2. Telegram will prompt for connection confirmation
3. Click «Connect»

For **`tg://proxy?server=...`**:
1. Copy the link and send it to «Saved Messages» or any chat
2. Click the link
3. Telegram will prompt for connection confirmation
4. Click «Connect»

For **Telegram Mobile**:  
1. Go to `Settings` → `Data and Storage` → `Proxy Settings` at the bottom
2. Select `Add Proxy` → Choose `MTProto Proxy`
3. Enter your server IP, port, and secret
4. Save and connect

For **Telegram Desktop**:  
1. Go to `Settings` → `Advanced` → `Connection Type` → `Use Custom Proxy`
2. Select `Add Proxy` → Choose `MTProto Proxy`
3. Enter your server IP, port, and secret
4. Save and connect

## Management Commands

- Start:
```
sudo systemctl start mtproxy
```
- Stop:
```
sudo systemctl stop mtproxy
```
- Restart:
```
sudo systemctl restart mtproxy
```
- Status:
```
sudo systemctl status mtproxy
```
- Logs:
```
sudo journalctl -u mtproxy -f
```
- Update config:
```
sudo mtproxy-update
```
- Check external port:
```
sudo ss -tulnp | grep mtproto-proxy
```
- Change port:
```
sudo install_mtproxy_english.sh reinstall
```
- Update secret:
```
sudo install_mtproxy_english.sh update-secret
```
- Complete removal:
```
sudo install_mtproxy_english.sh delete
```

***

Like the project? Support the author via [CloudTips](https://pay.cloudtips.ru/p/8ec8a87c) or [Yoomoney](https://yoomoney.ru/to/41001945296522) for a cup of coffee ☕
