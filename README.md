<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/6b94e3d9-12b9-4111-92cc-11f6326f4c1e">
    <img src="https://github.com/user-attachments/assets/6b94e3d9-12b9-4111-92cc-11f6326f4c1e" alt="English">
  </picture>
</div>

<h1 align="center">
  <a href="https://github.com/Internet-Helper/MTProto-MTProxy-Telegram/blob/main/README.en.md">English README (click on me)</a>
</h1>

# Установка для Debian 10-12 или Ubuntu 20.04-24.04

> [!IMPORTANT] 
> Данный материал подготовлен в научно-технических целях. Использование предоставленных материалов в целях отличных от ознакомления может являться нарушением действующего законодательства.  
> Автор не несет ответственности за неправомерное использование данного материала!

## О MTProxy
**MTProxy** — официальный прокси-сервер от Telegram, созданный на базе MTProto.  
Официальный репозиторий [TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy) устарел так как имеет проблемы при компиляции.  
Этот скрипт создан с целью автоматизировать установку и устранить проблему совместимости для современных систем, предлагая ряд улучшений.

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

# Установка dos2unix (если еще не установлен)
sudo apt update && sudo apt install -y dos2unix

# Исправление окончаний строк
dos2unix install_mtproxy_russian.sh

# Дать права на выполнение
chmod +x install_mtproxy_russian.sh

# Запустить скрипт
sudo /bin/bash ./install_mtproxy_russian.sh
```

После обновления и установки необходимых пакетов скрипт предложит выбрать внешний и внутренний порт на ваше усмотрение:

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
