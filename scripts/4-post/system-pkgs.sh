#!/bin/bash
# System Packages Script
# Author: ssnow
# Date: 2024
# Description: System packages script for Arch Linux installation

set -eo pipefail  # Exit on error, pipe failure

# Determine the correct path to lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

# Source the library functions
# shellcheck source=../../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Enable dry run mode for testing purposes (set to false to disable)
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"

    # Define packages to install
declare -A PACKAGE_GROUPS
PACKAGE_GROUPS=(
    ["base"]="eza fzf zoxide bat exa"
    ["system_tools"]="reflector openssh rsync"
    ["boot"]="plymouth grub os-prober"
    ["bluetooth"]="bluez bluez-utils"
    ["audio"]="pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack"
    ["utilities"]="fastfetch ntp cronie ${TERMINAL} kitty thunar"
    ["browser"]="firefox"
    ["desktop"]=""
    ["development"]="git vim neovim"
    ["office"]="libreoffice-fresh pinta"
    ["multimedia"]="vlc"
    ["communication"]="discord thunderbird"
    ["security"]="bitwarden"
    ["networking"]="networkmanager network-manager-applet dhclient"
    ["printer"]="cups"
    ["scanner"]=""
    ["virtualization"]="qemu virt-manager"
    ["containerization"]="docker"
    ["fonts"]="terminus-font ttf-font-awesome ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd ttf-meslo-nerd ttf-firacode-nerd ttf-nerd-fonts-symbols-common"
    ["filesystem"]="dosfstools ntfs-3g"
    ["xdg"]="xdg-user-dirs"
    ["theme"]="papirus-icon-theme"
    ["gaming"]="steam lutris"
)
# User-configurable options
INSTALL_GROUPS=(
    "base" 
    "bluetooth" 
    "audio" 
    "utilities" 
    "browser" 
    "development" 
    "office" 
    "multimedia" 
    "communication" 
    "security" 
    "networking" 
    "printer"  
    "fonts" 
    "filesystem" 
    "xdg"
)  # Default groups

# Function to install packages
install_package_group() {
    local group_name="$1"
    local packages="${PACKAGE_GROUPS[$group_name]}"
    # Check if packages are defined for the group
    if [ -n "$packages" ]; then
        print_message INFO "Installing $group_name packages: $packages"
        execute_process "Install $group_name packages" \
            --use-chroot \
            --error-message "Failed to install $group_name packages" \
            --success-message "$group_name packages installed successfully" \
            "pacman -S --noconfirm --needed $packages"
    else
        print_message WARNING "No packages defined for group: $group_name"
    fi
}
# Function to install all selected package groups
# Modify the install_selected_packages function
install_selected_packages() {
    print_message INFO "Starting package installation"
    # Install packages for each group
    for group in "${INSTALL_GROUPS[@]}"; do
        if [[ -v "PACKAGE_GROUPS[$group]" ]]; then
            print_message INFO "Installing group: $group"
            install_package_group "$group"
        else
            print_message WARNING "Skipping unknown package group: $group"
        fi
    done
    print_message OK "Package installation completed"
}
# Function to execute commands with error handling
main() {
    process_init "System Packages"
    print_message INFO "Starting system packages process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    install_selected_packages || { print_message ERROR "System packages process failed"; return 1; }

    print_message OK "System packages process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?