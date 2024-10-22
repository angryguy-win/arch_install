#!/usr/bin/env bash
set -euo pipefail

# This script automates the creation and installation of an Arch Linux VM using QEMU/KVM
# Author: Your Name
# Date: 2024
# Description: Automates VM setup with minimal user interaction

# Install required packages
echo "Installing required packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm qemu qemu-arch-extra libvirt virt-install virt-manager dnsmasq ebtables iptables

# Enable and start libvirtd service
echo "Enabling and starting libvirtd service..."
sudo systemctl enable --now libvirtd

# Add current user to libvirt and kvm groups
echo "Adding user $(whoami) to libvirt and kvm groups..."
sudo usermod -aG libvirt,kvm "$(whoami)"

# You might need to re-login for group changes to take effect
if ! groups | grep -q "\b\(libvirt\|kvm\)\b"; then
    echo "Please log out and log back in for group changes to take effect."
    exit 1
fi

# Create directories for VM images and ISOs
DEFAULT_DISK_DIRECTORY="$HOME/KVM_VMs"
DEFAULT_ISO_DIRECTORY="$HOME/ISOs"

mkdir -p "$DEFAULT_DISK_DIRECTORY"
mkdir -p "$DEFAULT_ISO_DIRECTORY"

# Download the latest Arch Linux ISO if not present
ISO_FILE="$DEFAULT_ISO_DIRECTORY/archlinux.iso"
if [[ ! -f "$ISO_FILE" ]]; then
    echo "Arch Linux ISO not found. Downloading..."
    curl -L -o "$ISO_FILE" https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
fi

# Create archinstall config for automated installation
ARCHINSTALL_CONFIG="$DEFAULT_ISO_DIRECTORY/archinstall_config.json"
cat > "$ARCHINSTALL_CONFIG" <<EOF
{
    "language": "en_US",
    "keyboard": "us",
    "mirror-region": "United States",
    "timezone": "America/Toronto",
    "bootloader": "systemd-bootctl",
    "filesystem": "ext4",
    "disk-setup": {
        "disk": "/dev/vda",
        "wipe": true,
        "partitions": {
            "bios": {
                "boot": true,
                "size": null
            },
            "root": {
                "size": null
            }
        }
    },
    "users": {
        "root": {
            "password": "password"
        },
        "user": {
            "username": "archuser",
            "password": "password",
            "sudo": true
        }
    },
    "packages": ["base", "linux", "linux-firmware", "vim", "networkmanager"],
    "services": ["NetworkManager"]
}
EOF

# Define VM parameters
VM_NAME="archlinux"
VCPU="2"
RAM="4096"
DISK_SIZE="40G"
DISK_PATH="$DEFAULT_DISK_DIRECTORY/${VM_NAME}.qcow2"

# Create virtual disk if it doesn't exist
if [[ ! -f "$DISK_PATH" ]]; then
    echo "Creating virtual disk..."
    qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

# Create temporary directory for the custom ISO
ISO_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf -- "$ISO_BUILD_DIR"' EXIT

# Mount the original ISO
sudo mount -o loop "$ISO_FILE" "$ISO_BUILD_DIR"

# Copy ISO contents to a new directory
ISO_CUSTOM_DIR="$DEFAULT_ISO_DIRECTORY/archiso_custom"
mkdir -p "$ISO_CUSTOM_DIR"
rsync -a "$ISO_BUILD_DIR/" "$ISO_CUSTOM_DIR/"

# Unmount the original ISO
sudo umount "$ISO_BUILD_DIR"

# Place the archinstall config into the new ISO's archinstall directory
mkdir -p "$ISO_CUSTOM_DIR/archinstall"
cp "$ARCHINSTALL_CONFIG" "$ISO_CUSTOM_DIR/archinstall/config.json"

# Modify syslinux boot menu to automate installation
sed -i 's/\\ archisolabel=.*/& archinstall_sessions=/archinstall/config.json/' "$ISO_CUSTOM_DIR/loader/entries/archiso-x86_64.conf"

# Create the custom ISO
CUSTOM_ISO_FILE="$DEFAULT_ISO_DIRECTORY/archlinux_custom.iso"
echo "Creating custom Arch Linux ISO with automated installation..."
genisoimage -V "ARCH_$(date +%Y%m)" \
    -J -r -o "$CUSTOM_ISO_FILE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "$ISO_CUSTOM_DIR"

# Install the VM
echo "Creating and starting the virtual machine..."
virt-install \
    --name "$VM_NAME" \
    --os-variant archlinux \
    --virt-type kvm \
    --cpu host \
    --ram "$RAM" \
    --vcpus "$VCPU" \
    --graphics none \
    --console pty,target_type=serial \
    --disk path="$DISK_PATH,format=qcow2" \
    --cdrom "$CUSTOM_ISO_FILE" \
    --network network=default \
    --noautoconsole \
    --wait -1

echo "Virtual machine '$VM_NAME' has been created and is installing Arch Linux automatically."

# Optionally, wait for installation to complete
echo "Waiting for the virtual machine to shut down after installation..."
virsh dominfo "$VM_NAME" | grep 'State' | grep -q 'running'
while [ $? -eq 0 ]; do
    sleep 10
    virsh dominfo "$VM_NAME" | grep 'State' | grep -q 'running'
done

echo "Installation complete. Starting the virtual machine..."
virsh start "$VM_NAME"

echo "Arch Linux VM '$VM_NAME' is up and running. You can connect via console or SSH."
