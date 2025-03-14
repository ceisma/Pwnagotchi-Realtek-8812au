#!/bin/bash
# install-service.sh: Prepares a one-time systemd service for sys-setup.sh.
# Must be run as root.

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (e.g., using sudo)."
  exit 1
fi

# Prompt for installation directory; default is /home/pi/scripts
read -p "Enter installation directory [/home/pi/scripts]: " install_dir
install_dir=${install_dir:-/home/pi/scripts}

# Determine installer root (the directory where this script is located)
installer_root="$(cd "$(dirname "$0")" && pwd)"

# Save the chosen installation directory so sys-setup.sh can use it
echo "$install_dir" > "$installer_root/install_dir.conf"

# Create a one-time systemd service unit file
service_file="/etc/systemd/system/one-time-installer.service"
cat > "$service_file" <<EOF
[Unit]
Description=One-Time System Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=$installer_root/sys-setup.sh $install_dir

[Install]
WantedBy=multi-user.target
EOF

echo "IMPORTANT:"
echo "  1. Your Pwnagotchi will reboot after the next step! For a successful installation, plug in your USB Realtek (RTL8812AU) adapter during the reboot."
echo "  2. In order for your Realtek (RTL8812AU) adapter to work, you must plug in the adapter after your Pwnagotchi has booted up. Otherwise, it will not work. If your adapter is not recognized, remove it and plug it back in, then wait a few seconds. If it still doesn't work, please check pwnlog. The adapter should be assigned as wlan1mon."
read -p "Press Y to proceed with installation and reboot: " confirm
if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
  echo "Installation aborted."
  exit 1
fi

# Enable the one-time service
systemctl enable one-time-installer.service

echo "Installation will proceed in 10 seconds. Please prepare accordingly."
sleep 10

echo "Rebooting now..."
reboot
