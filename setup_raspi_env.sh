#!/bin/bash
# Enviroment setup script for RaspberryPi 64bit (test enviroment)

# system variables
OS_ID=$(. /etc/os-release && echo "$ID")
OS_ARCH=$(dpkg --print-architecture)

# USB serial devices variables
# USB to RS485
RS485_SYMLINK_NAME="ttyRS485" 
RS485_VENDOR_ID="0403"
RS485_PRODUCT_ID="6001"
RS485_SERIAL_NUM="BG00WS8T"
# BEG Modules Controller
BEGCON_SYMLINK_NAME="ttyBEGCON" 
BEGCON_VENDOR_ID="10c4"
BEGCON_PRODUCT_ID="ea60"
BEGCON_SERIAL_NUM="0001"

# Check OS
if [[ $OS_ID != "debian" || $OS_ARCH != "arm64" ]]; then
	echo "This script is intended to run on a arm64 debian-based OS."
	exit 1
fi

# Check for root
if [[ $EUID -ne 0 ]]; then
	echo "This script must run as root."
	exit 1
fi

# Dependences
echo "Installing dependences..."
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings

# Add Docker's GPG key
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
	curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	chmod a+r /etc/apt/keyrings/docker.asc
fi
echo "Docker's GPG key added."

# Add the repository to Apt sources
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
	echo \
  		"deb [arch=$OS_ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  		$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  		tee /etc/apt/sources.list.d/docker.list > /dev/null
	apt-get update
fi
echo "Docker's repositroy added to apt sources."

# Install Docker latest version
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker in latest version."

# setup USB symlinks
SRULES_FILE="/etc/udev/rules.d/99-usb-serial.rules"
if ! grep -q $RS485_SYMLINK_NAME $SRULES_FILE; then
	cat <<EOF >> "$SRULES_FILE"
SUBSYSTEM=="tty", ATTRS{idVendor}=="$RS485_VENDOR_ID", ATTRS{idProduct}=="$RS485_PRODUCT_ID", ATTRS{serial}=="$RS485_SERIAL_NUM", SYMLINK+="$RS485_SYMLINK_NAME"
EOF
echo "Added udev rule for $RS485_SYMLINK_NAME"
fi

if ! grep -q $BEGCON_SYMLINK_NAME $SRULES_FILE; then
	cat <<EOF >> "$SRULES_FILE"
SUBSYSTEM=="tty", ATTRS{idVendor}=="$BEGCON_VENDOR_ID", ATTRS{idProduct}=="$BEGCON_PRODUCT_ID", ATTRS{serial}=="$BEGCON_SERIAL_NUM", SYMLINK+="$BEGCON_SYMLINK_NAME"
EOF
echo "Added udev rules for $BEGCON_SYMLINK_NAME"
fi

# Reload and trigger udev
udevadm control --reload-rules
udevadm trigger

