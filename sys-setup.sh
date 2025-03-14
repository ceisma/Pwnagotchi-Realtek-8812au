#!/bin/bash
# sys-setup.sh: One-time system setup script executed on boot via systemd.
# It installs helper scripts, auto-detects the USB WiFi adapter details, and creates the udev rule.
# All messages are logged since no terminal is attached.

# The installation directory is provided as the first argument.
if [ -z "$1" ]; then
  echo "Error: Installation directory argument missing." >> "$(dirname "$0")/error.log"
  exit 1
fi
install_dir="$1"

installer_root="$(cd "$(dirname "$0")" && pwd)"
error_log="$installer_root/error.log"
success_log="$installer_root/success.log"

{
  echo "===== sys-setup.sh started at $(date) ====="
  echo "Installation directory: $install_dir"

  # Create installation directory if it doesn't exist.
  mkdir -p "$install_dir"

  # Verify the helper scripts directory exists.
  if [ ! -d "$installer_root/scripts" ]; then
    echo "Error: 'scripts' directory not found in $installer_root" >&2
    exit 1
  fi

  # Copy helper scripts to the chosen install directory.
  cp "$installer_root/scripts/plug-script.sh" "$install_dir"
  cp "$installer_root/scripts/unplug-script.sh" "$install_dir"
  chmod +x "$install_dir/plug-script.sh" "$install_dir/unplug-script.sh"
  echo "Copied plug-script.sh and unplug-script.sh to $install_dir"

  # Auto-detect the USB WiFi adapter.
  # Exclude known root hubs by filtering out "Linux Foundation".
  usb_line=$(lsusb | grep -v "Linux Foundation" | head -n 1)
  if [ -z "$usb_line" ]; then
    echo "Error: No additional USB device detected. Ensure the WiFi adapter is plugged in." >&2
    exit 1
  fi

  # Extract Bus and Device numbers from the lsusb output.
  bus=$(echo "$usb_line" | awk '{print $2}')
  device=$(echo "$usb_line" | awk '{print $4}' | tr -d ':')
  
  # Extract idVendor and idProduct from the "ID" field.
  id_field=$(echo "$usb_line" | awk '{print $6}')
  id_vendor=$(echo "$id_field" | cut -d: -f1)
  id_product=$(echo "$id_field" | cut -d: -f2)
  
  echo "Detected USB device details:"
  echo "  idVendor: $id_vendor"
  echo "  idProduct: $id_product"
  echo "  Bus: $bus, Device: $device"

  # Retrieve the DEVPATH using udevadm info.
  dev_path=$(udevadm info -q path -n /dev/bus/usb/$bus/$device)
  if [ -z "$dev_path" ]; then
    echo "Error: Could not retrieve DEVPATH for the USB device." >&2
    exit 1
  fi
  echo "Detected DEVPATH: $dev_path"

  # Generate the udev rule file with detected values.
  rule_file="/etc/udev/rules.d/70-usb-wifi-dongle.rules"
  cat > "$rule_file" <<EOF
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="$id_vendor", ATTRS{idProduct}=="$id_product", RUN+="$install_dir/plug-script.sh"
ACTION=="remove", ENV{DEVPATH}=="$dev_path", RUN+="$install_dir/unplug-script.sh"
EOF
  echo "udev rule file created at $rule_file"

  # Remove the one-time systemd service so this script does not run again.
  service_file="/etc/systemd/system/one-time-installer.service"
  if [ -f "$service_file" ]; then
    rm "$service_file"
    systemctl daemon-reload
    echo "Removed one-time service file $service_file"
  else
    echo "One-time service file not found; skipping removal."
  fi

  echo "===== sys-setup.sh completed successfully at $(date) ====="
} >> "$success_log" 2>> "$error_log"

logger "Installation completed. Rebooting in 3 seconds."

sleep 3
reboot
