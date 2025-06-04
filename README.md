# Установка для Debian 10-12 или Ubuntu 20.04-24.04

> [!TIP]
> **Installation for Debian 10-12 or Ubuntu 20.04-24.04 → [ENGLISH README](https://github.com/Internet-Helper/MTProto-MTProxy-Telegram/blob/main/README.en.md)**

***

Нравится проект? Поддержи автора через [CloudTips](https://pay.cloudtips.ru/p/8ec8a87c) или [Юмани](https://yoomoney.ru/to/41001945296522) скинув на чашечку кофе ☕ 

***

## О MTProxy
**MTProxy** — официальный прокси-сервер от Telegram, созданный на базе MTProto для доступа к Telegram в регионах с ограничениями в сети.  
Официальный репозиторий [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) устарел и имеет проблемы при компиляции поэтому данный скрипт установки решает эти проблемы с улучшениями.

## Основные функции скрипта

- Устанавливает, переустанавливает или полностью удаляет MTProxy.
- Позволяет выбрать внешний и внутренний порт при установке и переустановке.
- Настраивает автоматическое ежедневное обновление конфигурации через `cron` для стабильной работы прокси.
- Позволяет обновить секрет MTProxy одной командой.
- Генерирует ссылки для подключения после установки.

## Требования системы

- **ОС**: Debian 10, 11, 12 или Ubuntu 20.04, 22.04, 22.10, 23.04, 24.04
- **ОЗУ**: От 512 МБ и выше
- **ЦП**: 1 ядро и выше
- **Диск**: 1 ГБ
- **Сеть**: Белый статический IP

## Инструкция по установке

Запустите команды через консоль:

```
# Загрузка скрипта
wget -O install_mtproxy_russian.sh https://raw.githubusercontent.com/Internet-Helper/MTProto-MTProxy-Telegram/refs/heads/main/install_mtproxy_russian.sh

# Дать права на выполнение
chmod +x install_mtproxy_russian.sh

# Запустить скрипт
sudo ./install_mtproxy_russian.sh
```

После обновления и установки необходимых пакетов скрипт предложит выбрать вынешний и внутренний порт на ваше усмотрение:

![image](https://github.com/user-attachments/assets/d80e8ca9-98d2-4529-bc2b-0eed3519dc43)

## Настройка и использование

После запуска **MTProxy** вы получите следующие данные:

![image](https://github.com/user-attachments/assets/fc791989-12d9-441a-a4a2-1cb31e32abc4)

## Настройка и использование прокси:

**Инструкция для `https://t.me/proxy?server=...`**:
1. Кликните по ссылке или отправьте в любой чат, где хотите ей поделиться
2. Telegram запросит подтверждение для подключения
3. Нажмите «Подключиться»

**Инструкция для `tg://proxy?server=...`**:
1. Скопируйте ссылку и отправьте в `«Избранное»` или в любой чат, где хотите поделиться прокси
2. Кликните по ссылке
3. Telegram запросит подтверждение для подключения
4. Нажмите «Подключиться»

**Инструкция для ручного ввода в Telegram (Mobile)**:  
1. `Настройки` → `Данные и память` → `Настройки прокси`
2. `Добавить прокси` → Выберите `Прокси MTProto`
3. Введите IP вашего сервера, внешний порт и секрет
4. Сохраните и подключитесь

**Инструкция для ручного ввода в Telegram (Desktop)**:  
1. `Настройки` → `Продвинутые настройки` → `Тип соединения` → `Использовать собственный прокси`
2. `Добавить прокси` → Выберите `MTProto`
3. Введите IP вашего сервера, внешний порт и секрет
4. Сохраните и подключитесь

## Команды управления

• Старт:
```
sudo systemctl start mtproxy
```
• Стоп:
```
sudo systemctl stop mtproxy
```
• Перезапуск:
```
sudo systemctl restart mtproxy
```
• Статус:
```
sudo systemctl status mtproxy
```
• Логи:
```
sudo journalctl -u mtproxy -f
```
• Обновить конфиг:
```
sudo mtproxy-update
```
• Проверить работу внешнего порта:
```
sudo ss -tulnp | grep mtproto-proxy
```
• Изменить порт:
```
sudo install_mtproxy_russian.sh reinstall
```
• Изменить секрет:
```
sudo install_mtproxy_russian.sh update-secret
```
• Удалить полностью:
```
sudo install_mtproxy_russian.sh delete
```

***

Нравится проект? Поддержи автора через [CloudTips](https://pay.cloudtips.ru/p/8ec8a87c) или [Юмани](https://yoomoney.ru/to/41001945296522) скинув на чашечку кофе ☕ 
