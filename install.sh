#!/bin/bash
# Installer for plug-script.sh and unplug-script.sh and setting up udev rules

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please run with sudo or as root."
  exit 1
fi

# Prompt user for installation directory, defaulting to /home/pi/scripts
read -p "Enter installation directory [/home/pi/scripts]: " install_dir
install_dir=${install_dir:-/home/pi/scripts}

# Create the target directory if it doesn't exist.
mkdir -p "$install_dir"

# Determine the installer root (directory where this script is located)
installer_root="$(cd "$(dirname "$0")" && pwd)"

# Copy the scripts from the installer root's 'scripts' directory
cp "$installer_root/scripts/plug-script.sh" "$install_dir"
cp "$installer_root/scripts/unplug-script.sh" "$install_dir"

# Make sure the scripts are executable
chmod +x "$install_dir/plug-script.sh" "$install_dir/unplug-script.sh"

# Create udev rule file using the provided installation directory path
rule_file="/etc/udev/rules.d/70-usb-wifi-dongle.rules"
cat > "$rule_file" <<EOF
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="8812", RUN+="$install_dir/plug-script.sh"
ACTION=="remove", ENV{DEVPATH}=="/devices/platform/soc/3f980000.usb/usb1/1-1", RUN+="$install_dir/unplug-script.sh"
EOF

echo "Installation complete."
echo "Scripts installed in: $install_dir"
echo "udev rules file created at: $rule_file"
