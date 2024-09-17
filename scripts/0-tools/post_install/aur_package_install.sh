#!/bin/bash
# AUR Packages Script
# Author: ssnow
# Date: 2024
# Description: AUR packages script for Arch Linux installation

set -eo pipefail  # Exit on error, pipe failure

# Determine the correct path to lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

# Source the library functions
if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Enable dry run mode for testing purposes (set to false to disable)
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"

# Path to the AUR package groups TOML file
AUR_GROUPS_FILE="$ARCH_DIR/aur_package_groups.toml"

# Function to read TOML file and update AUR_INSTALL_GROUPS
read_aur_toml_and_update_groups() {
    local toml_file="$1"
    local temp_groups=()

    while IFS= read -r line; do
        if [[ $line =~ ^\[([^]]+)\]$ ]]; then
            current_group="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^install[[:space:]]*=[[:space:]]*true$ ]]; then
            temp_groups+=("$current_group")
        fi
    done < "$toml_file"

    AUR_INSTALL_GROUPS=("${temp_groups[@]}")
}

# Function to install AUR packages
install_aur_package_group() {
    local group_name="$1"
    local packages

    # Extract packages for the group from the TOML file
    packages=$(awk -v group="$group_name" '
        $0 ~ "^\\[" group "\\]" {
            in_group = 1
            next
        }
        in_group && /^packages[[:space:]]*=/ {
            gsub(/[\[\]"]/, "")
            split($0, a, "=")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[2])
            print a[2]
            exit
        }
    ' "$AUR_GROUPS_FILE")
    
    if [ -n "$packages" ]; then
        print_message INFO "Installing AUR $group_name packages: $packages"
        execute_process "Install AUR $group_name packages" \
            --use-chroot \
            --error-message "Failed to install AUR $group_name packages" \
            --success-message "AUR $group_name packages installed successfully" \
            "su - $USERNAME -c 'yay -S --noconfirm --needed $packages'"
    else
        print_message WARNING "No AUR packages defined for group: $group_name"
    fi
}

# Function to install all selected AUR package groups
install_selected_aur_packages() {
    print_message INFO "Starting AUR package installation"
    for group in "${AUR_INSTALL_GROUPS[@]}"; do
        print_message INFO "Installing AUR group: $group"
        install_aur_package_group "$group"
    done
    print_message OK "AUR package installation completed"
}

# Main function
main() {
    process_init "AUR Packages"
    show_logo "AUR Packages"
    print_message INFO "Starting AUR packages process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    # Load configuration
    local vars=(USERNAME)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    # Read AUR package groups from TOML file
    read_aur_toml_and_update_groups "$AUR_GROUPS_FILE" || { print_message ERROR "Failed to read AUR groups"; return 1; }

    # Install yay AUR helper if not already installed
    if ! command -v yay &> /dev/null; then
        print_message INFO "Installing yay AUR helper"
        execute_process "Install yay" \
            --use-chroot \
            --error-message "Failed to install yay" \
            --success-message "yay installed successfully" \
            "su - $USERNAME -c 'git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm'"
    fi

    install_selected_aur_packages || { print_message ERROR "AUR packages process failed"; return 1; }

    print_message OK "AUR packages process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?