#!/bin/bash

# Script for Debian 10-12 and Ubuntu 20.04-24.04

# Checking Strings for Unix Endings (LF) on Linux
if grep -q $'\r' "$0" 2>/dev/null; then
    echo "Windows line endings detected, fixing..."
    sed -i 's/\r$//' "$0"
    echo "Restart with fixed line endings..."
    exec bash "$0" "$@"
fi

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# Function to print a colored message
print_status() {
    echo -e "${GREEN}* ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# --- Self-installation of the script to PATH ---
# If the script is not run from /usr/local/bin, it copies itself there and restarts.
# This allows using delete/reinstall/update-secret commands from any directory.

INSTALL_PATH="/usr/local/bin"
SCRIPT_NAME="$(basename "$0")"
INSTALLED_SCRIPT_PATH="$INSTALL_PATH/$SCRIPT_NAME"

# Check if the current script is already installed in /usr/local/bin
# If not, copy it and restart
if [ "$(readlink -f "$0")" != "$INSTALLED_SCRIPT_PATH" ]; then
    print_header "Script Preparation"
    print_status "Installing the script to $INSTALL_PATH for convenient management commands..."
    # Check if the directory exists and is writable
    if [ ! -d "$INSTALL_PATH" ] || [ ! -w "$INSTALL_PATH" ]; then
        print_error "Directory $INSTALL_PATH does not exist or is not writable. Script installation is not possible."
        print_warning "Management commands may only work by running the script with './$SCRIPT_NAME' from the current directory."
        # Continue execution without copying
    else
        if sudo cp "$0" "$INSTALLED_SCRIPT_PATH"; then
            sudo chmod +x "$INSTALLED_SCRIPT_PATH"
            print_status "Script copied. Restarting from $INSTALL_PATH..."
            # Restart the script with the same arguments, replacing the current process
            # Use exec so the new process replaces the old one
            exec sudo "$INSTALLED_SCRIPT_PATH" "$@"
        else
            print_error "Failed to copy script to $INSTALL_PATH."
            print_warning "Management commands will only work by running the script from its current location with the full path or via ./"
            # Continue execution from the current location
        fi
    fi
fi
# --- End of self-installation ---


# --- Management Functions ---

# Function to update the main MTProxy secret
update_mtproxy_secret() {
    print_header "Updating MTProxy secret..."
    local service_file="/etc/systemd/system/mtproxy.service"

    if [ ! -f "$service_file" ]; then
        print_error "Systemd service file '$service_file' not found."
        print_error "Make sure MTProxy is installed."
        exit 1
    fi

    print_status "Generating new secret..."
    NEW_SECRET=$(head -c 16 /dev/urandom | xxd -ps)

    print_status "Updating service unit file '$service_file'..."
    # Use sed to replace the old secret with the new one in the ExecStart line
    # Look for the pattern -S <32 hex characters> and replace it
    if sudo sed -i "s|-S [a-f0-9]\{32\}|-S ${NEW_SECRET}|" "$service_file"; then
        print_status "Secret successfully updated in the unit file."

        # Update the secret also in /etc/mtproxy/config file for reference
        if [ -f "/etc/mtproxy/config" ]; then
            sudo sed -i "s/^SECRET=.*/SECRET=$NEW_SECRET/" "/etc/mtproxy/config" 2>/dev/null || true
            print_status "Secret updated in /etc/mtproxy/config."
        fi

        print_status "Reloading systemd unit files..."
        sudo systemctl daemon-reload

        print_status "Restarting MTProxy service..."
        if sudo systemctl restart mtproxy; then
            print_status "MTProxy service successfully restarted with the new secret!"
            echo
            print_header "MTProxy secret update complete!"
            echo -e "${GREEN}* ${NC}New MTProxy secret:"
            echo -e "${GREEN}* ${NC}${NEW_SECRET}"
            print_warning "Remove the old MTProxy in Telegram!"
            # Attempt to generate a new link if IP is available
            local CURRENT_EXTERNAL_PORT=$(grep -oP '(?<=-H )[0-9]+' "$service_file" | head -1)
            local SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_PUBLIC_IP_ADDRESS")
            if [ -n "$CURRENT_EXTERNAL_PORT" ] && [ "$SERVER_IP" != "YOUR_PUBLIC_IP_ADDRESS" ]; then
                 echo -e "${GREEN}* ${NC}New link:"
                 echo -e "${GREEN}* ${NC}https://t.me/proxy?server=${SERVER_IP}&port=${CURRENT_EXTERNAL_PORT}&secret=${NEW_SECRET}"
                 echo -e "${GREEN}* ${NC}New link ONLY for the app:"
                 echo -e "${GREEN}* ${NC}tg://proxy?server=${SERVER_IP}&port=${CURRENT_EXTERNAL_PORT}&secret=${NEW_SECRET}"
            else
                 print_warning "Failed to generate a new link automatically (port not found in unit or IP)."
                 print_warning "New secret: ${NEW_SECRET}"
            fi

        else
            print_error "Failed to restart MTProxy service after updating the secret."
            print_error "Check logs: sudo journalctl -u mtproxy"
            exit 1
        fi
    else
        print_error "Failed to update secret in service unit file '$service_file'."
        print_error "Check file content and permissions."
        exit 1
    fi
}


uninstall_mtproxy() {
    local silent_prompt=false
    if [ "$1" == "--silent-prompt" ]; then
        silent_prompt=true
    else
        print_header "Uninstalling MTProxy"
        print_warning "This will completely remove MTProxy and all its files."
        echo "Enter 'y' or '+' to confirm and press Enter:"
        read -r confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "+" ]]; then
            print_status "Uninstallation cancelled."
            exit 0
        fi
    fi

    print_status "Stopping and disabling service..."
    sudo systemctl stop mtproxy 2>/dev/null || true
    sudo systemctl disable mtproxy 2>/dev/null || true
    sudo rm -f /etc/systemd/system/mtproxy.service 2>/dev/null || true
    sudo systemctl daemon-reload || true # allow failure if daemon-reload fails for some reason

    print_status "Removing binary..."
    sudo rm -f /usr/local/bin/mtproto-proxy 2>/dev/null || true
    print_status "Clearing binary privileges..."
    sudo setcap -r /usr/local/bin/mtproto-proxy 2>/dev/null || true # Clearing capabilities

    print_status "Removing configs and directories..."
    sudo rm -rf /etc/mtproxy 2>/dev/null || true
    sudo rm -rf /var/lib/mtproxy 2>/dev/null || true
    sudo rm -rf /var/log/mtproxy 2>/dev/null || true
    print_status "Removing logrotate config..."
    sudo rm -f /etc/logrotate.d/mtproxy 2>/dev/null || true
    print_status "Removing update script..."
    sudo rm -f /usr/local/bin/mtproxy-update 2>/dev/null || true
    print_status "Removing cron job..."
    sudo rm -f /etc/cron.d/mtproxy-update 2>/dev/null || true


    print_status "Removing user 'mtproxy'..."
    if id "mtproxy" &>/dev/null; then
        sudo userdel mtproxy 2>/dev/null || print_warning "Failed to remove user 'mtproxy'. It might still own files."
    fi

    print_status "Cleaning up sysctl..."
    SYSCTL_FILE="/etc/sysctl.conf"
    # Remove the exact line added by the script, if it exists
    if grep -q "^net.core.somaxconn[[:space:]]*=.*1024" "$SYSCTL_FILE"; then
         sudo sed -i '/^net.core.somaxconn[[:space:]]*=.*1024/d' "$SYSCTL_FILE"
         sudo sysctl -p || print_warning "Failed to apply sysctl changes."
    fi

    print_warning "Firewall settings (UFW/iptables/cloud) are NOT removed."
    if ! $silent_prompt; then
        print_header "MTProxy uninstallation complete."
    fi
}

reinstall_mtproxy() {
    print_header "Reinstalling MTProxy"
    print_warning "This will completely remove the current MTProxy installation and start a new one."
    echo "Enter 'y' or '+' to confirm and press Enter:"
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" && "$confirm" != "+" ]]; then
        print_status "Reinstallation cancelled."
        exit 0
    fi

    uninstall_mtproxy --silent-prompt
    print_header "Starting new MTProxy installation..."
}

# --- Command Line Argument Handling ---
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
        print_header "Starting MTProxy installation"
        ;;
esac

# --- Main installation logic starts here ---

# OS Check
if ! grep -q -E "Debian|Ubuntu" /etc/os-release; then
    print_error "This script is intended for Debian or Ubuntu only."
    exit 1
fi

# Determine Ubuntu version
UBUNTU_VERSION=$(grep "VERSION_ID" /etc/os-release | cut -d '"' -f2)

# If Ubuntu 23.x, fix sources.list
if [[ "$UBUNTU_VERSION" =~ ^23 ]]; then
    print_header "Ubuntu $UBUNTU_VERSION detected, applying fixes"

    # Create a backup of sources.list
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    print_status "sources.list backup created."

    # Update server addresses in sources.list
    sudo sed -i 's|http://.*archive.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    sudo sed -i 's|http://security.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    sudo sed -i 's|http://archive.ubuntu.com|http://old-releases.ubuntu.com|g' /etc/apt/sources.list
    print_status "sources.list file updated to support old repositories."

    # Update package list
    print_status "Updating package list..."
    sudo apt update
fi

# Package Update
print_status "Updating packages..."
sudo apt update -y && sudo apt upgrade -y

# Dependency Installation
print_status "Installing dependencies..."
sudo apt install -y git build-essential libssl-dev zlib1g-dev curl wget \
    libc6-dev gcc-multilib make cmake pkg-config netcat-openbsd xxd iproute2 dos2unix

# Creating mtproxy user for secure service execution
print_status "mtproxy user (for security)..."
if ! id "mtproxy" &>/dev/null; then
    sudo useradd -r -s /bin/false -d /var/lib/mtproxy -M mtproxy
    sudo mkdir -p /var/lib/mtproxy
    sudo chown mtproxy:mtproxy /var/lib/mtproxy
    print_status "'mtproxy' user created."
else
    print_status "'mtproxy' user already exists."
fi

# --- Port Selection and Check ---
EXTERNAL_PORT=""
while true; do
    print_header "External Port Selection"
    echo "Enter the desired external port (default is 443)."
    echo -n "If the port is suitable, just press Enter: "
    read -r EXTERNAL_PORT_INPUT
    if [ -z "$EXTERNAL_PORT_INPUT" ]; then EXTERNAL_PORT_INPUT=443; fi
    if ! [[ "$EXTERNAL_PORT_INPUT" =~ ^[0-9]+$ ]] || (( EXTERNAL_PORT_INPUT <= 0 || EXTERNAL_PORT_INPUT > 65535 )); then
        print_error "Invalid port: $EXTERNAL_PORT_INPUT."
        continue
    fi
    print_status "Checking external port $EXTERNAL_PORT_INPUT availability..."
    if sudo ss -tulnp | grep -q ":$EXTERNAL_PORT_INPUT\b"; then
         print_error "Port $EXTERNAL_PORT_INPUT is busy. Please choose another."
    else
         print_status "Port $EXTERNAL_PORT_INPUT is free."
         EXTERNAL_PORT="$EXTERNAL_PORT_INPUT"
         break
    fi
done

INTERNAL_PORT=""
DEFAULT_INTERNAL_PORT=8008
while true; do
    print_header "Internal Port Selection"
    echo "Enter the desired internal port (default is ${DEFAULT_INTERNAL_PORT})."
    echo -n "If the port is suitable, just press Enter: "
    read -r INTERNAL_PORT_INPUT
    if [ -z "$INTERNAL_PORT_INPUT" ]; then INTERNAL_PORT_INPUT=$DEFAULT_INTERNAL_PORT; fi
    if ! [[ "$INTERNAL_PORT_INPUT" =~ ^[0-9]+$ ]] || (( INTERNAL_PORT_INPUT <= 0 || INTERNAL_PORT_INPUT > 65535 )); then
        print_error "Invalid port: $INTERNAL_PORT_INPUT."
        continue
    fi
    if [ "$INTERNAL_PORT_INPUT" -eq "$EXTERNAL_PORT" ]; then
        print_error "Internal port ($INTERNAL_PORT_INPUT) cannot be the same as the external port ($EXTERNAL_PORT)."
        continue
    fi
    print_status "Checking internal port $INTERNAL_PORT_INPUT availability..."
    if sudo ss -tulnp | grep -q ":$INTERNAL_PORT_INPUT\b"; then
         print_error "Port $INTERNAL_PORT_INPUT is busy. Please choose another."
    else
         print_status "Port $INTERNAL_PORT_INPUT is free."
         INTERNAL_PORT="$INTERNAL_PORT_INPUT"
         break
    fi
done


# Building MTProxy from source
print_header "Building MTProxy"
cd /tmp
rm -rf MTProxy MTProxy-community 2>/dev/null || true
BUILD_SUCCESS=false

print_status "Building from GetPageSpeed/MTProxy..."
if git clone https://github.com/GetPageSpeed/MTProxy.git MTProxy-community; then
    cd MTProxy-community
    if [ -f "Makefile" ]; then sed -i 's/-Werror//g' Makefile 2>/dev/null || true; fi
    if make -j$(nproc) 2>/dev/null; then BUILD_SUCCESS=true; print_status "Success (GetPageSpeed)."; else print_warning "Failed (GetPageSpeed). make output:"; make -j$(nproc); cd /tmp; fi
fi

if [ "$BUILD_SUCCESS" = false ]; then
    print_status "Building from TelegramMessenger/MTProxy..."
    if git clone https://github.com/TelegramMessenger/MTProxy.git; then
        cd MTProxy
        if [ -f "Makefile" ]; then sed -i 's/-Werror//g' Makefile 2>/dev/null || true; fi
        if [ -f "Makefile" ]; then grep -q -- "-fcommon" Makefile || sed -i 's/CFLAGS =/CFLAGS = -fcommon/g' Makefile 2>/dev/null || true; fi
        if [ -f "Makefile" ]; then sed -i 's/-march=native/-march=native -fcommon/g' Makefile 2>/dev/null || true; fi
        find . -name "*.c" -exec sed -i '1i#include <string.h>' {} \; 2>/dev/null || true
        find . -name "*.c" -exec sed -i '1i#include <unistd.h>' {} \; 2>/dev/null || true

        if make -j$(nproc) CFLAGS="-fcommon -Wno-error" 2>/dev/null; then BUILD_SUCCESS=true; print_status "Success (TelegramMessenger)."; else print_warning "Failed (TelegramMessenger). make output:"; make -j$(nproc) CFLAGS="-fcommon -Wno-error"; print_warning "Attempting with min flags..."; if make CC=gcc CFLAGS="-O2 -fcommon -w"; then BUILD_SUCCESS=true; print_status "Success (min flags)."; fi; fi
    fi
fi

if [ "$BUILD_SUCCESS" = false ]; then
    print_error "Failed to build MTProxy."
    print_error "Check the make output above. Consider alternatives."
    exit 1
fi

# Installing binary and configuring
print_header "Installation and Configuration"
sudo mkdir -p /etc/mtproxy /var/log/mtproxy 2>/dev/null || true

print_status "Copying binary..."
MTPROXY_BINARY_PATH=""
if [ -f "objs/bin/mtproto-proxy" ]; then MTPROXY_BINARY_PATH="objs/bin/mtproto-proxy"; fi
if [ -z "$MTPROXY_BINARY_PATH" ] && [ -f "mtproto-proxy" ]; then MTPROXY_BINARY_PATH="mtproto-proxy"; fi
if [ -z "$MTPROXY_BINARY_PATH" ] && [ -f "bin/mtproto-proxy" ]; then MTPROXY_BINARY_PATH="bin/mtproto-proxy"; fi

if [ -n "$MTPROXY_BINARY_PATH" ] && [ -f "$MTPROXY_BINARY_PATH" ]; then
     sudo cp "$MTPROXY_BINARY_PATH" /usr/local/bin/mtproto-proxy
     sudo chmod +x /usr/local/bin/mtproto-proxy
     print_status "Binary installed."
else
    print_error "Binary not found!"
    exit 1
fi

print_status "Generating secret..."
SECRET=$(head -c 16 /dev/urandom | xxd -ps)
echo "SECRET=$SECRET" | sudo tee /etc/mtproxy/config > /dev/null
print_status "Secret generated."

print_status "Downloading Telegram configs..."
sudo curl -s https://core.telegram.org/getProxySecret -o /etc/mtproxy/proxy-secret || print_warning "Failed to download proxy-secret."
sudo curl -s https://core.telegram.org/getProxyConfig -o /etc/mtproxy/proxy-multi.conf || print_warning "Failed to download proxy-multi.conf."

print_status "Setting permissions..."
sudo chown -R mtproxy:mtproxy /etc/mtproxy /var/log/mtproxy /var/lib/mtproxy 2>/dev/null || true
sudo chmod 600 /etc/mtproxy/* 2>/dev/null || true

print_status "Setting port privileges..."
if (( EXTERNAL_PORT <= 1024 )); then
    sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/mtproto-proxy
    print_status "CAP_NET_BIND_SERVICE capabilities set."
else
    sudo setcap 'cap_net_bind_service=-ep' /usr/local/bin/mtproto-proxy 2>/dev/null || true
    print_status "CAP_NET_BIND_SERVICE not required."
fi

print_status "Creating systemd service..."
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
print_status "systemd service created."

print_status "Reloading systemd..."
sudo systemctl daemon-reload
print_status "Enabling service on boot..."
sudo systemctl enable mtproxy

print_status "Creating update script..."
sudo tee /usr/local/bin/mtproxy-update > /dev/null <<'EOF'
#!/bin/bash

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
print_status() { echo -e "${GREEN}* ${NC}$1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_status "Updating MTProxy configuration..."
CONFIG_DIR="/etc/mtproxy"

if ! command -v curl &>/dev/null; then print_error "Error: curl not found."; exit 1; fi
if [ ! -d "$CONFIG_DIR" ]; then print_error "Error: Directory $CONFIG_DIR does not exist."; exit 1; fi

# Download to temporary files
if curl -s https://core.telegram.org/getProxySecret -o "$CONFIG_DIR/proxy-secret.new"; then
    mv "$CONFIG_DIR/proxy-secret.new" "$CONFIG_DIR/proxy-secret"
    print_status "proxy-secret updated."
else
    print_warning "Failed to download proxy-secret."
fi

if curl -s https://core.telegram.org/getProxyConfig -o "$CONFIG_DIR/proxy-multi.conf.new"; then
    mv "$CONFIG_DIR/proxy-multi.conf.new" "$CONFIG_DIR/proxy-multi.conf"
    print_status "proxy-multi.conf updated."
else
    print_warning "Failed to download proxy-multi.conf."
fi

# Set permissions and ownership
if [ -f "$CONFIG_DIR/proxy-secret" ]; then sudo chown mtproxy:mtproxy "$CONFIG_DIR/proxy-secret" 2>/dev/null || true; sudo chmod 600 "$CONFIG_DIR/proxy-secret" 2>/dev/null || true; fi
if [ -f "$CONFIG_DIR/proxy-multi.conf" ]; then sudo chown mtproxy:mtproxy "$CONFIG_DIR/proxy-multi.conf" 2>/dev/null || true; sudo chmod 600 "$CONFIG_DIR/proxy-multi.conf" 2>/dev/null || true; fi
print_status "Permissions updated."

print_status "Restarting service..."
if systemctl restart mtproxy; then print_status "Service restarted."; else print_error "Failed to restart service. Check logs."; exit 1; fi
print_status "Configuration update complete."

EOF
sudo chmod +x /usr/local/bin/mtproxy-update
print_status "Update script created."

# --- Configuring daily updates via cron ---
print_status "Configuring daily configuration update (cron)..."
if [ ! -f "/etc/cron.d/mtproxy-update" ] || ! grep -q "/usr/local/bin/mtproxy-update" /etc/cron.d/mtproxy-update; then
    sudo tee /etc/cron.d/mtproxy-update > /dev/null <<EOF
0 3 * * * root /usr/local/bin/mtproxy-update > /dev/null 2>&1
EOF
    print_status "Daily update configured for 03:00 UTC."
else
    print_status "Cron job for daily update already exists."
fi


# Log Rotation Configuration
print_status "Configuring log rotation..."
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
print_status "Logrotate configuration added."

# Firewall Configuration (if ufw is installed)
if command -v ufw &> /dev/null; then
    print_status "Configuring UFW firewall..."
    sudo ufw allow $EXTERNAL_PORT/tcp comment "MTProxy External Port" || print_warning "Failed to add UFW rule for port $EXTERNAL_PORT."
    print_status "UFW rule added for external port $EXTERNAL_PORT/tcp."
    print_warning "If UFW is disabled, enable it: sudo ufw enable"
elif command -v iptables &> /dev/null; then
    print_status "iptables detected. Add rules for ${EXTERNAL_PORT}/tcp manually."
else
    print_warning "Firewall not detected. Open the external port ${EXTERNAL_PORT}/tcp manually in your system and with your provider."
fi

print_status "Starting MTProxy service..."
if sudo systemctl start mtproxy; then
    print_status "MTProxy service started."
else
    print_error "Failed to start MTProxy service. Check logs: sudo journalctl -u mtproxy -f"
    exit 1
fi

# Optimizations after successful startup
print_header "Optimizations"
print_status "Descriptor limits are set in the systemd unit."

print_status "Configuring network parameters (net.core.somaxconn)..."
SYSCTL_FILE="/etc/sysctl.conf"
SYSCTL_SETTING="net.core.somaxconn = 1024"
if grep -q "^net.core.somaxconn[[:space:]]*=" "$SYSCTL_FILE"; then
    sudo sed -i 's/^net.core.somaxconn[[:space:]]*=.*$/net.core.somaxconn = 1024/' "$SYSCTL_FILE"
    print_status "net.core.somaxconn updated."
else
    echo "$SYSCTL_SETTING" | sudo tee -a "$SYSCTL_FILE" > /dev/null
    print_status "net.core.somaxconn = 1024 added."
fi
print_status "Applying network parameters..."
sudo sysctl -p || print_warning "Failed to apply sysctl -p."


# Final Output
print_header "MTProxy Installation Complete!"
echo -e "${GREEN}* ${NC}MTProxy has been successfully installed and is running in the background."

print_header "Management Commands"
echo "• Start:"
echo "sudo systemctl start mtproxy"
echo "• Stop:"
echo "sudo systemctl stop mtproxy"
echo "• Restart:"
echo "sudo systemctl restart mtproxy"
echo "• Status:"
echo "sudo systemctl status mtproxy"
echo "• Logs:"
echo "sudo journalctl -u mtproxy -f"
echo "• Update config:"
echo "sudo mtproxy-update"
echo "• Check external port status:"
echo "sudo ss -tulnp | grep mtproto-proxy"
echo "• Change port:"
echo "sudo $SCRIPT_NAME reinstall"
echo "• Change secret:"
echo "sudo $SCRIPT_NAME update-secret"
echo "• Uninstall completely:"
echo "sudo $SCRIPT_NAME delete"

print_header "MTProxy Details"
echo -e "${BLUE}IMPORTANT REMINDER!${NC}"
echo -e "${BLUE}Open the selected EXTERNAL port (${EXTERNAL_PORT}/tcp) in your Firewall and/or with your provider, if necessary!${NC}"
echo -e "${GREEN}*${NC} External Port (Internet <-> MTProxy): ${EXTERNAL_PORT}"
echo -e "${GREEN}*${NC} Internal Port (MTProxy <-> Telegram): ${INTERNAL_PORT}"
# Get server IP address for links
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_PUBLIC_IP_ADDRESS")
if [ "$SERVER_IP" = "YOUR_PUBLIC_IP_ADDRESS" ]; then
    print_warning "Could not determine public IP."
    print_warning "Use your actual public IP instead of 'YOUR_PUBLIC_IP_ADDRESS'."
fi
echo -e "${GREEN}*${NC} Server Public IP: ${SERVER_IP}"
echo -e "${GREEN}*${NC} MTProxy Secret: ${SECRET}"
echo -e "${GREEN}*${NC} Link:"
echo -e "${GREEN}*${NC} https://t.me/proxy?server=${SERVER_IP}&port=${EXTERNAL_PORT}&secret=${SECRET}"
echo -e "${GREEN}*${NC} Link ONLY for the app:"
echo -e "${GREEN}*${NC} tg://proxy?server=${SERVER_IP}&port=${EXTERNAL_PORT}&secret=${SECRET}"

print_header "Enjoy!"