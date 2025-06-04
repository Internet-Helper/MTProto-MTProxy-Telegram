#!/bin/bash

# Скрипт для Debian 10-12 и Ubuntu 20.04-24.04

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Нет цвета

# Функция для вывода цветного сообщения
print_status() {
    echo -e "${GREEN}* ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"
}

print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# --- Самостоятельная установка скрипта в PATH ---
# Если скрипт запущен не из /usr/local/bin, он копирует себя туда и перезапускается.
# Это позволяет использовать команды delete/reinstall/update-secret из любого каталога.

INSTALL_PATH="/usr/local/bin"
SCRIPT_NAME="$(basename "$0")"
INSTALLED_SCRIPT_PATH="$INSTALL_PATH/$SCRIPT_NAME"

# Проверяем, является ли текущий скрипт уже установленным в /usr/local/bin
# Если нет, копируем его и перезапускаем
if [ "$(readlink -f "$0")" != "$INSTALLED_SCRIPT_PATH" ]; then
    print_header "Подготовка скрипта"
    print_status "Установка скрипта в $INSTALL_PATH для удобных команд управления..."
    # Проверяем, существует ли каталог и доступен ли для записи
    if [ ! -d "$INSTALL_PATH" ] || [ ! -w "$INSTALL_PATH" ]; then
        print_error "Каталог $INSTALL_PATH не существует или недоступен для записи. Установка скрипта невозможна."
        print_warning "Команды управления могут работать только при запуске скрипта с './$SCRIPT_NAME' из текущего каталога."
        # Продолжаем выполнение без копирования
    else
        if sudo cp "$0" "$INSTALLED_SCRIPT_PATH"; then
            sudo chmod +x "$INSTALLED_SCRIPT_PATH"
            print_status "Скрипт скопирован. Перезапуск из $INSTALL_PATH..."
            # Перезапускаем скрипт с теми же аргументами, заменяя текущий процесс
            # Используем exec, чтобы новый процесс заменил старый
            exec sudo "$INSTALLED_SCRIPT_PATH" "$@"
        else
            print_error "Не удалось скопировать скрипт в $INSTALL_PATH."
            print_warning "Команды управления будут работать только при запуске скрипта из его текущего расположения с полным путем или через ./"
            # Продолжаем выполнение из текущего расположения
        fi
    fi
fi
# --- Конец самостоятельной установки ---


# --- Функции управления ---

# Функция для обновления основного секрета MTProxy
update_mtproxy_secret() {
    print_header "Обновление секрета MTProxy..."
    local service_file="/etc/systemd/system/mtproxy.service"

    if [ ! -f "$service_file" ]; then
        print_error "Файл сервиса systemd '$service_file' не найден."
        print_error "Убедитесь, что MTProxy установлен."
        exit 1
    fi

    print_status "Генерация нового секрета..."
    NEW_SECRET=$(head -c 16 /dev/urandom | xxd -ps)

    print_status "Обновление unit файла сервиса '$service_file'..."
    # Используем sed для замены старого секрета на новый в строке ExecStart
    # Ищем паттерн -S <32 шестнадцатеричных символов> и заменяем его
    if sudo sed -i "s|-S [a-f0-9]\{32\}|-S ${NEW_SECRET}|" "$service_file"; then
        print_status "Секрет успешно обновлен в unit файле."

        # Обновляем секрет также в файле /etc/mtproxy/config для справки
        if [ -f "/etc/mtproxy/config" ]; then
            sudo sed -i "s/^SECRET=.*/SECRET=$NEW_SECRET/" "/etc/mtproxy/config" 2>/dev/null || true
            print_status "Секрет обновлен в /etc/mtproxy/config."
        fi

        print_status "Перезагрузка unit файлов systemd..."
        sudo systemctl daemon-reload

        print_status "Перезапуск сервиса MTProxy..."
        if sudo systemctl restart mtproxy; then
            print_status "Сервис MTProxy успешно перезапущен с новым секретом!"
            echo
            print_header "Обновление секрета MTProxy успешно завершено!"
            echo -e "${GREEN}* ${NC}Новый секрет MTProxy:"
            echo -e "${GREEN}* ${NC}${NEW_SECRET}"
            print_warning "Удалите старый MTProxy в Telegram!"
            # Попытка сгенерировать новую ссылку, если IP доступен
            local CURRENT_EXTERNAL_PORT=$(grep -oP '(?<=-H )[0-9]+' "$service_file" | head -1)
            local SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "ВАШ_ПУБЛИЧНЫЙ_IP_АДРЕС")
            if [ -n "$CURRENT_EXTERNAL_PORT" ] && [ "$SERVER_IP" != "ВАШ_ПУБЛИЧНЫЙ_IP_АДРЕС" ]; then
                 echo -e "${GREEN}* ${NC}Новая ссылка:"
                 echo -e "${GREEN}* ${NC}https://t.me/proxy?server=${SERVER_IP}&port=${CURRENT_EXTERNAL_PORT}&secret=${NEW_SECRET}"
                 echo -e "${GREEN}* ${NC}Новая ссылка ТОЛЬКО для приложения:"
                 echo -e "${GREEN}* ${NC}tg://proxy?server=${SERVER_IP}&port=${CURRENT_EXTERNAL_PORT}&secret=${NEW_SECRET}"
            else
                 print_warning "Не удалось сгенерировать новую ссылку автоматически (не найден порт в юните или IP)."
                 print_warning "Новый секрет: ${NEW_SECRET}"
            fi

        else
            print_error "Не удалось перезапустить сервис MTProxy после обновления секрета."
            print_error "Проверьте логи: sudo journalctl -u mtproxy"
            exit 1
        fi
    else
        print_error "Не удалось обновить секрет в unit файле сервиса '$service_file'."
        print_error "Проверьте содержимое файла и права доступа."
        exit 1
    fi
}


uninstall_mtproxy() {
    local silent_prompt=false
    if [ "$1" == "--silent-prompt" ]; then
        silent_prompt=true
    else
        print_header "Удаление MTProxy"
        print_warning "Это полностью удалит MTProxy и все его файлы."
        echo "Введите 'y' или '+' для подтверждения и нажмите Enter:"
        read -r confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "+" ]]; then
            print_status "Удаление отменено."
            exit 0
        fi
    fi

    print_status "Остановка и отключение сервиса..."
    sudo systemctl stop mtproxy 2>/dev/null || true
    sudo systemctl disable mtproxy 2>/dev/null || true
    sudo rm -f /etc/systemd/system/mtproxy.service 2>/dev/null || true
    sudo systemctl daemon-reload || true # allow failure if daemon-reload fails for some reason

    print_status "Удаление бинарника..."
    sudo rm -f /usr/local/bin/mtproto-proxy 2>/dev/null || true
    print_status "Очистка привилегий бинарника..."
    sudo setcap -r /usr/local/bin/mtproto-proxy 2>/dev/null || true # Очистка capabilities

    print_status "Удаление конфигов и каталогов..."
    sudo rm -rf /etc/mtproxy 2>/dev/null || true
    sudo rm -rf /var/lib/mtproxy 2>/dev/null || true
    sudo rm -rf /var/log/mtproxy 2>/dev/null || true
    print_status "Удаление конфига logrotate..."
    sudo rm -f /etc/logrotate.d/mtproxy 2>/dev/null || true
    print_status "Удаление скрипта обновления..."
    sudo rm -f /usr/local/bin/mtproxy-update 2>/dev/null || true
    print_status "Удаление задачи cron..."
    sudo rm -f /etc/cron.d/mtproxy-update 2>/dev/null || true


    print_status "Удаление пользователя 'mtproxy'..."
    if id "mtproxy" &>/dev/null; then
        sudo userdel mtproxy 2>/dev/null || print_warning "Не удалось удалить пользователя 'mtproxy'. Возможно, он все еще владеет файлами."
    fi

    print_status "Очистка sysctl..."
    SYSCTL_FILE="/etc/sysctl.conf"
    # Удаляем именно ту строку, которую добавлял скрипт, если она есть
    if grep -q "^net.core.somaxconn[[:space:]]*=.*1024" "$SYSCTL_FILE"; then
         sudo sed -i '/^net.core.somaxconn[[:space:]]*=.*1024/d' "$SYSCTL_FILE"
         sudo sysctl -p || print_warning "Не удалось применить изменения sysctl."
    fi

    print_warning "Настройки файрвола (UFW/iptables/облачные) НЕ удалены."
    if ! $silent_prompt; then
        print_header "Удаление MTProxy завершено."
    fi
}

reinstall_mtproxy() {
    print_header "Переустановка MTProxy"
    print_warning "Это полностью удалит текущую установку MTProxy и начнет новую установку."
    echo "Введите 'y' или '+' для подтверждения и нажмите Enter:"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "+" ]]; then
        print_status "Переустановка отменена."
        exit 0
    fi

    uninstall_mtproxy --silent-prompt
    print_header "Запуск новой установки MTProxy..."
}

# --- Обработка аргументов командной строки ---
case "$1" in
    delete)
        uninstall_mtproxy
        exit 0
        ;;
    reinstall)
        reinstall_mtproxy
        ;;
    update-secret)
        update_mtproxy_secret
        exit 0
        ;;
    *)
        print_header "Запуск установки MTProxy"
        ;;
esac

# --- Основная логика установки начинается здесь ---

# Проверка ОС
if ! grep -q -E "Debian|Ubuntu" /etc/os-release; then
    print_error "Скрипт предназначен только для Debian или Ubuntu."
    exit 1
fi

# Определяем версию Ubuntu
UBUNTU_VERSION=$(grep "VERSION_ID" /etc/os-release | cut -d '"' -f2)

# Если Ubuntu 23.x, исправляем sources.list
if [[ "$UBUNTU_VERSION" =~ ^23 ]]; then
    print_header "Обнаружена Ubuntu $UBUNTU_VERSION, вносим исправления"

    # Создаём резервную копию sources.list
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    print_status "Резервная копия sources.list создана."

    # Обновляем адреса серверов в sources.list
    sudo sed -i 's|http://.*archive.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    sudo sed -i 's|http://security.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    sudo sed -i 's|http://archive.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    print_status "Файл sources.list обновлён для поддержки устаревших репозиториев."

    # Обновляем список пакетов
    print_status "Обновляем список пакетов..."
    sudo apt update
fi

# Обновление пакетов
print_status "Обновление пакетов..."
sudo apt update -y && sudo apt upgrade -y

# Установка зависимостей
print_status "Установка зависимостей..."
sudo apt install -y git build-essential libssl-dev zlib1g-dev curl wget \
    libc6-dev gcc-multilib make cmake pkg-config netcat-openbsd xxd iproute2

# Создание пользователя mtproxy для безопасного запуска сервиса
print_status "Пользователь mtproxy (для безопасности)..."
if ! id "mtproxy" &>/dev/null; then
    sudo useradd -r -s /bin/false -d /var/lib/mtproxy -M mtproxy
    sudo mkdir -p /var/lib/mtproxy
    sudo chown mtproxy:mtproxy /var/lib/mtproxy
    print_status "'mtproxy' создан."
else
    print_status "'mtproxy' уже существует."
fi

# --- Выбор и проверка портов ---
EXTERNAL_PORT=""
while true; do
    print_header "Выбор внешнего порта"
    echo "Напишите желаемый внешний порт (по умолчанию используется 443)."
    echo -n "Если порт подходит — просто нажмите Enter: "
    read -r EXTERNAL_PORT_INPUT
    if [ -z "$EXTERNAL_PORT_INPUT" ]; then EXTERNAL_PORT_INPUT=443; fi
    if ! [[ "$EXTERNAL_PORT_INPUT" =~ ^[0-9]+$ ]] || (( EXTERNAL_PORT_INPUT <= 0 || EXTERNAL_PORT_INPUT > 65535 )); then
        print_error "Неверный порт: $EXTERNAL_PORT_INPUT."
        continue
    fi
    print_status "Проверка занятости внешнего порта $EXTERNAL_PORT_INPUT..."
    if sudo ss -tulnp | grep -q ":$EXTERNAL_PORT_INPUT\b"; then
         print_error "Порт $EXTERNAL_PORT_INPUT занят. Выберите другой."
    else
         print_status "Порт $EXTERNAL_PORT_INPUT свободен."
         EXTERNAL_PORT="$EXTERNAL_PORT_INPUT"
         break
    fi
done

INTERNAL_PORT=""
DEFAULT_INTERNAL_PORT=8008
while true; do
    print_header "Выбор внутреннего порта"
    echo "Напишите желаемый внутренний порт (по умолчанию используется ${DEFAULT_INTERNAL_PORT})."
    echo -n "Если порт подходит — просто нажмите Enter: "
    read -r INTERNAL_PORT_INPUT
    if [ -z "$INTERNAL_PORT_INPUT" ]; then INTERNAL_PORT_INPUT=$DEFAULT_INTERNAL_PORT; fi
    if ! [[ "$INTERNAL_PORT_INPUT" =~ ^[0-9]+$ ]] || (( INTERNAL_PORT_INPUT <= 0 || INTERNAL_PORT_INPUT > 65535 )); then
        print_error "Неверный порт: $INTERNAL_PORT_INPUT."
        continue
    fi
    if [ "$INTERNAL_PORT_INPUT" -eq "$EXTERNAL_PORT" ]; then
        print_error "Внутренний порт ($INTERNAL_PORT_INPUT) не может совпадать с внешним ($EXTERNAL_PORT)."
        continue
    fi
    print_status "Проверка занятости внутреннего порта $INTERNAL_PORT_INPUT..."
    if sudo ss -tulnp | grep -q ":$INTERNAL_PORT_INPUT\b"; then
         print_error "Порт $INTERNAL_PORT_INPUT занят. Выберите другой."
    else
         print_status "Порт $INTERNAL_PORT_INPUT свободен."
         INTERNAL_PORT="$INTERNAL_PORT_INPUT"
         break
    fi
done


# Сборка MTProxy из исходников
print_header "Сборка MTProxy"
cd /tmp
rm -rf MTProxy MTProxy-community 2>/dev/null || true
BUILD_SUCCESS=false

print_status "Сборка из GetPageSpeed/MTProxy..."
if git clone https://github.com/GetPageSpeed/MTProxy.git MTProxy-community; then
    cd MTProxy-community
    if [ -f "Makefile" ]; then sed -i 's/-Werror//g' Makefile 2>/dev/null || true; fi
    if make -j$(nproc) 2>/dev/null; then BUILD_SUCCESS=true; print_status "Успех (GetPageSpeed)."; else print_warning "Не удалось (GetPageSpeed). Вывод make:"; make -j$(nproc); cd /tmp; fi
fi

if [ "$BUILD_SUCCESS" = false ]; then
    print_status "Сборка из TelegramMessenger/MTProxy..."
    if git clone https://github.com/TelegramMessenger/MTProxy.git; then
        cd MTProxy
        if [ -f "Makefile" ]; then sed -i 's/-Werror//g' Makefile 2>/dev/null || true; fi
        if [ -f "Makefile" ]; then grep -q -- "-fcommon" Makefile || sed -i 's/CFLAGS =/CFLAGS = -fcommon/g' Makefile 2>/dev/null || true; fi
        if [ -f "Makefile" ]; then sed -i 's/-march=native/-march=native -fcommon/g' Makefile 2>/dev/null || true; fi
        find . -name "*.c" -exec sed -i '1i#include <string.h>' {} \; 2>/dev/null || true
        find . -name "*.c" -exec sed -i '1i#include <unistd.h>' {} \; 2>/dev/null || true

        if make -j$(nproc) CFLAGS="-fcommon -Wno-error" 2>/dev/null; then BUILD_SUCCESS=true; print_status "Успех (TelegramMessenger)."; else print_warning "Не удалось (TelegramMessenger). Вывод make:"; make -j$(nproc) CFLAGS="-fcommon -Wno-error"; print_warning "Попытка с мин. флагами..."; if make CC=gcc CFLAGS="-O2 -fcommon -w"; then BUILD_SUCCESS=true; print_status "Успех (мин. флаги)."; fi; fi
    fi
fi

if [ "$BUILD_SUCCESS" = false ]; then
    print_error "Не удалось собрать MTProxy."
    print_error "Проверьте вывод make выше. Рассмотрите альтернативы."
    exit 1
fi

# Установка бинарника и настройка
print_header "Установка и настройка"
sudo mkdir -p /etc/mtproxy /var/log/mtproxy 2>/dev/null || true

print_status "Копирование бинарника..."
MTPROXY_BINARY_PATH=""
if [ -f "objs/bin/mtproto-proxy" ]; then MTPROXY_BINARY_PATH="objs/bin/mtproto-proxy"; fi
if [ -z "$MTPROXY_BINARY_PATH" ] && [ -f "mtproto-proxy" ]; then MTPROXY_BINARY_PATH="mtproto-proxy"; fi
if [ -z "$MTPROXY_BINARY_PATH" ] && [ -f "bin/mtproto-proxy" ]; then MTPROXY_BINARY_PATH="bin/mtproto-proxy"; fi

if [ -n "$MTPROXY_BINARY_PATH" ] && [ -f "$MTPROXY_BINARY_PATH" ]; then
     sudo cp "$MTPROXY_BINARY_PATH" /usr/local/bin/mtproto-proxy
     sudo chmod +x /usr/local/bin/mtproto-proxy
     print_status "Бинарник установлен."
else
    print_error "Бинарник не найден!"
    exit 1
fi

print_status "Генерация секрета..."
SECRET=$(head -c 16 /dev/urandom | xxd -ps)
echo "SECRET=$SECRET" | sudo tee /etc/mtproxy/config > /dev/null
print_status "Секрет сгенерирован."

print_status "Загрузка конфигов Telegram..."
sudo curl -s https://core.telegram.org/getProxySecret -o /etc/mtproxy/proxy-secret || print_warning "Не удалось скачать proxy-secret."
sudo curl -s https://core.telegram.org/getProxyConfig -o /etc/mtproxy/proxy-multi.conf || print_warning "Не удалось скачать proxy-multi.conf."

print_status "Установка прав доступа..."
sudo chown -R mtproxy:mtproxy /etc/mtproxy /var/log/mtproxy /var/lib/mtproxy 2>/dev/null || true
sudo chmod 600 /etc/mtproxy/* 2>/dev/null || true

print_status "Настройка привилегий портов..."
if (( EXTERNAL_PORT <= 1024 )); then
    sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/mtproto-proxy
    print_status "Права CAP_NET_BIND_SERVICE установлены."
else
    sudo setcap 'cap_net_bind_service=-ep' /usr/local/bin/mtproto-proxy 2>/dev/null || true
    print_status "CAP_NET_BIND_SERVICE не требуется."
fi

print_status "Создание systemd сервиса..."
sudo tee /etc/systemd/system/mtproxy.service > /dev/null <<EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
User=mtproxy
Group=mtproxy
WorkingDirectory=/var/lib/mtproxy
ExecStart=/usr/local/bin/mtproto-proxy -u mtproxy -p ${INTERNAL_PORT} -H ${EXTERNAL_PORT} -S ${SECRET} --aes-pwd /etc/mtproxy/proxy-secret /etc/mtproxy/proxy-multi.conf -M 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mtproxy
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
print_status "systemd сервис создан."

print_status "Перезагрузка systemd..."
sudo systemctl daemon-reload
print_status "Включение сервиса в автозагрузку..."
sudo systemctl enable mtproxy

print_status "Создание скрипта обновления..."
sudo tee /usr/local/bin/mtproxy-update > /dev/null <<'EOF'
#!/bin/bash

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
print_status() { echo -e "${GREEN}* ${NC}$1"; }
print_warning() { echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"; }
print_error() { echo -e "${RED}[ОШИБКА]${NC} $1"; }

print_status "Обновление конфигурации MTProxy..."
CONFIG_DIR="/etc/mtproxy"

if ! command -v curl &>/dev/null; then print_error "Ошибка: curl не найден."; exit 1; fi
if [ ! -d "$CONFIG_DIR" ]; then print_error "Ошибка: Каталог $CONFIG_DIR не существует."; exit 1; fi

# Скачиваем во временные файлы
if curl -s https://core.telegram.org/getProxySecret -o "$CONFIG_DIR/proxy-secret.new"; then
    mv "$CONFIG_DIR/proxy-secret.new" "$CONFIG_DIR/proxy-secret"
    print_status "proxy-secret обновлен."
else
    print_warning "Не удалось скачать proxy-secret."
fi

if curl -s https://core.telegram.org/getProxyConfig -o "$CONFIG_DIR/proxy-multi.conf.new"; then
    mv "$CONFIG_DIR/proxy-multi.conf.new" "$CONFIG_DIR/proxy-multi.conf"
    print_status "proxy-multi.conf обновлен."
else
    print_warning "Не удалось скачать proxy-multi.conf."
fi

# Устанавливаем права и владельца
if [ -f "$CONFIG_DIR/proxy-secret" ]; then sudo chown mtproxy:mtproxy "$CONFIG_DIR/proxy-secret" 2>/dev/null || true; sudo chmod 600 "$CONFIG_DIR/proxy-secret" 2>/dev/null || true; fi
if [ -f "$CONFIG_DIR/proxy-multi.conf" ]; then sudo chown mtproxy:mtproxy "$CONFIG_DIR/proxy-multi.conf" 2>/dev/null || true; sudo chmod 600 "$CONFIG_DIR/proxy-multi.conf" 2>/dev/null || true; fi
print_status "Права доступа обновлены."

print_status "Перезапуск сервиса..."
if systemctl restart mtproxy; then print_status "Сервис перезапущен."; else print_error "Не удалось перезапустить сервис. Проверьте логи."; exit 1; fi
print_status "Обновление конфигурации завершено."

EOF
sudo chmod +x /usr/local/bin/mtproxy-update
print_status "Скрипт обновления создан."

# --- Настройка ежедневного обновления через cron ---
print_status "Настройка ежедневного обновления конфигурации (cron)..."
if [ ! -f "/etc/cron.d/mtproxy-update" ] || ! grep -q "/usr/local/bin/mtproxy-update" /etc/cron.d/mtproxy-update; then
    sudo tee /etc/cron.d/mtproxy-update > /dev/null <<EOF
0 3 * * * root /usr/local/bin/mtproxy-update > /dev/null 2>&1
EOF
    print_status "Ежедневное обновление настроено на 03:00 UTC."
else
    print_status "Задача cron для ежедневного обновления уже существует."
fi


# Настройка ротации логов
print_status "Настройка ротации логов..."
sudo tee /etc/logrotate.d/mtproxy > /dev/null <<EOF
/var/log/mtproxy/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 mtproxy mtproxy
    postrotate
        systemctl try-reload-or-restart mtproxy > /dev/null 2>&1 || true
    endscript
}
EOF
print_status "Настройка logrotate добавлена."

# Настройка файрвола (если установлен ufw)
if command -v ufw &> /dev/null; then
    print_status "Настройка файрвола UFW..."
    sudo ufw allow $EXTERNAL_PORT/tcp comment "MTProxy External Port" || print_warning "Не удалось добавить правило UFW для порта $EXTERNAL_PORT."
    print_status "Правило UFW добавлено для внешнего порта $EXTERNAL_PORT/tcp."
    print_warning "Если UFW выключен, включите его: sudo ufw enable"
elif command -v iptables &> /dev/null; then
    print_status "Обнаружен iptables. Добавьте правила для ${EXTERNAL_PORT}/tcp вручную."
else
    print_warning "Файрвол не обнаружен. Откройте внешний порт ${EXTERNAL_PORT}/tcp вручную в вашей системе и у провайдера."
fi

print_status "Запуск сервиса MTProxy..."
if sudo systemctl start mtproxy; then
    print_status "Сервис MTProxy запущен."
else
    print_error "Не удалось запустить сервис MTProxy. Проверьте логи: sudo journalctl -u mtproxy -f"
    exit 1
fi

# Оптимизации после успешного запуска
print_header "Оптимизации"
print_status "Лимиты дескрипторов установлены в systemd юните."

print_status "Настройка сетевых параметров (net.core.somaxconn)..."
SYSCTL_FILE="/etc/sysctl.conf"
SYSCTL_SETTING="net.core.somaxconn = 1024"
if grep -q "^net.core.somaxconn[[:space:]]*=" "$SYSCTL_FILE"; then
    sudo sed -i 's/^net.core.somaxconn[[:space:]]*=.*$/net.core.somaxconn = 1024/' "$SYSCTL_FILE"
    print_status "Обновлено net.core.somaxconn."
else
    echo "$SYSCTL_SETTING" | sudo tee -a "$SYSCTL_FILE" > /dev/null
    print_status "Добавлено net.core.somaxconn = 1024."
fi
print_status "Применение сетевых параметров..."
sudo sysctl -p || print_warning "Не удалось применить sysctl -p."


# Финальный вывод
print_header "Установка MTProxy завершена!"
echo -e "${GREEN}* ${NC}MTProxy успешно установлен и запущен в фоновом режиме."

print_header "Команды управления"
echo "• Старт:"
echo "sudo systemctl start mtproxy"
echo "• Стоп:"
echo "sudo systemctl stop mtproxy"
echo "• Перезапуск:"
echo "sudo systemctl restart mtproxy"
echo "• Статус:"
echo "sudo systemctl status mtproxy"
echo "• Логи:"
echo "sudo journalctl -u mtproxy -f"
echo "• Обновить конфиг:"
echo "sudo mtproxy-update"
echo "• Проверить работу внешнего порта:"
echo "sudo ss -tulnp | grep mtproto-proxy"
echo "• Изменить порт:"
echo "sudo $SCRIPT_NAME reinstall"
echo "• Изменить секрет:"
echo "sudo $SCRIPT_NAME update-secret"
echo "• Удалить полностью:"
echo "sudo $SCRIPT_NAME delete"

print_header "Сведения о MTProxy"
echo -e "${BLUE}ВАЖНОЕ НАПОМИНАНИЕ!${NC}"
echo -e "${BLUE}Откройте выбранный ВНЕШНИЙ порт (${EXTERNAL_PORT}/tcp) в Firewall и/или у вашего провайдера, если это необходимо!${NC}"
echo -e "${GREEN}*${NC} Внешний порт (Интернет <-> MTProxy): ${EXTERNAL_PORT}"
echo -e "${GREEN}*${NC} Внутренний порт (MTProxy <-> Telegram): ${INTERNAL_PORT}"
# Получение IP адреса сервера для ссылок
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "ВАШ_ПУБЛИЧНЫЙ_IP_АДРЕС")
if [ "$SERVER_IP" = "ВАШ_ПУБЛИЧНЫЙ_IP_АДРЕС" ]; then
    print_warning "Не удалось определить публичный IP."
    print_warning "Используйте ваш реальный публичный IP вместо 'ВАШ_ПУБЛИЧНЫЙ_IP_АДРЕС'."
fi
echo -e "${GREEN}*${NC} Публичный IP сервера: ${SERVER_IP}"
echo -e "${GREEN}*${NC} Секрет MTProxy: ${SECRET}"
echo -e "${GREEN}*${NC} Ссылка:"
echo -e "${GREEN}*${NC} https://t.me/proxy?server=${SERVER_IP}&port=${EXTERNAL_PORT}&secret=${SECRET}"
echo -e "${GREEN}*${NC} Ссылка ТОЛЬКО для приложения:"
echo -e "${GREEN}*${NC} tg://proxy?server=${SERVER_IP}&port=${EXTERNAL_PORT}&secret=${SECRET}"

print_header "Приятного использования!"