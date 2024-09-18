#!/bin/bash
# Pre-setup Script
# Author: ssnow
# Date: 2024
# Description: Pre-setup script for Arch Linux installation

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



initial_setup() {
    print_message INFO "Starting initial setup"
    # Initial setup
    execute_process "Initial setup" \
        --debug \
        --error-message "Initial setup failed" \
        --success-message "Initial setup completed" \
        "timedatectl set-ntp true" \
        "pacman -Sy archlinux-keyring --noconfirm" \
        "pacman -S --noconfirm --needed pacman-contrib terminus-font rsync reflector gptfdisk btrfs-progs glibc" \
        "setfont ter-v22b" \
        "sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf" \
        "pacman -Syy"
}
mirror_setup() {
    local country_iso
    country_iso="$1"
    # Mirror setup
    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        "curl -4 'https://ifconfig.co/country-iso' > COUNTRY_ISO" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup"
        

}
prepare_drive() {
    print_message INFO "Preparing drive"
    
    # Load the updated configuration
    load_config || { print_message ERROR "Failed to load config"; return 1; }
    
    # Now INSTALL_DEVICE should be correctly set
    local DEVICE="/dev/${INSTALL_DEVICE}"
    set_option "DEVICE" "$DEVICE" || { print_message ERROR "Failed to set DEVICE"; return 1; }
    print_message ACTION "Drive set to: " "$DEVICE"
    
    # Use $DEVICE instead of ${DEVICE} for consistency
    print_message ACTION "Partitions string set to: " "${DEVICE}p2, ${DEVICE}p3"
    set_option "PARTITION_EFI" "${DEVICE}p2" || { print_message ERROR "Failed to set PARTITION_EFI"; return 1; }
    set_option "PARTITION_ROOT" "${DEVICE}p3" || { print_message ERROR "Failed to set PARTITION_ROOT"; return 1; }
    set_option "PARTITION_HOME" "${DEVICE}p4" || { print_message ERROR "Failed to set PARTITION_HOME"; return 1; }
    set_option "PARTITION_SWAP" "${DEVICE}p5" || { print_message ERROR "Failed to set PARTITION_SWAP"; return 1; }
    
    # Load the config again to ensure all changes are reflected
    load_config || { print_message ERROR "Failed to load config"; return 1; }
}
main() {
    process_init "Pre-setup"
    show_logo "Pre-setup"
    print_message INFO "Starting pre-setup process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    # Load configuration
    local vars=(COUNTRY_ISO)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    initial_setup || { print_message ERROR "Initial setup failed"; return 1; }
    mirror_setup "$COUNTRY_ISO" || { print_message ERROR "Mirror setup failed"; return 1; }
    show_drive_list || { print_message ERROR "Drive selection failed"; return 1; }
    prepare_drive || { print_message ERROR "Drive preparation failed"; return 1; }

    print_message OK "Pre-setup process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?