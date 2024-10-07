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
# shellcheck source=../../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
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

    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        "curl -4 'https://ifconfig.co/country-iso' > COUNTRY_ISO" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup"
        

}
prepare_drive() {
    print_message INFO "Preparing drive"
    
    # Determine if we're dealing with a hdd/virtio drive or an ssd/nvme drive
    if [[ "$INSTALL_DEVICE" == nvme* ]]; then
        # NVME/SSD  drive
        DEVICE="/dev/${INSTALL_DEVICE}"
        PARTITION_EFI="${DEVICE}p2"
        PARTITION_ROOT="${DEVICE}p3"
        PARTITION_HOME="${DEVICE}p4"
        PARTITION_SWAP="${DEVICE}p5"
        MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    else
        # Physical/virt drive
        DEVICE="/dev/${INSTALL_DEVICE}"
        PARTITION_EFI="${DEVICE}2"
        PARTITION_ROOT="${DEVICE}3"
        PARTITION_HOME="${DEVICE}4"
        PARTITION_SWAP="${DEVICE}5"
        MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    fi

    set_option "DEVICE" "$DEVICE" || { print_message ERROR "Failed to set DEVICE"; return 1; }
    print_message ACTION "Drive set to: " "$DEVICE"
    
    print_message ACTION "Partitions string set to: " "${PARTITION_EFI}, ${PARTITION_ROOT}"
    set_option "DEVICE" "${DEVICE}" || { print_message ERROR "Failed to set DEVICE"; return 1; }
    set_option "PARTITION_EFI" "${PARTITION_EFI}" || { print_message ERROR "Failed to set PARTITION_EFI"; return 1; }
    set_option "PARTITION_ROOT" "${PARTITION_ROOT}" || { print_message ERROR "Failed to set PARTITION_ROOT"; return 1; }
    set_option "PARTITION_HOME" "${PARTITION_HOME}" || { print_message ERROR "Failed to set PARTITION_HOME"; return 1; }
    set_option "PARTITION_SWAP" "${PARTITION_SWAP}" || { print_message ERROR "Failed to set PARTITION_SWAP"; return 1; }
    set_option "MOUNT_OPTIONS" "${MOUNT_OPTIONS}" || { print_message ERROR "Failed to set MOUNT_OPTIONS"; return 1; }
    # Load the config again to ensure all changes are reflected
    load_config || { print_message ERROR "Failed to load config"; return 1; }
}
main() {
    process_init "Pre-setup"
    print_message INFO "Starting pre-setup process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    initial_setup || { print_message ERROR "Initial setup failed"; return 1; }
    mirror_setup || { print_message ERROR "Mirror setup failed"; return 1; }
    show_drive_list || { print_message ERROR "Drive selection failed"; return 1; }
    prepare_drive || { print_message ERROR "Drive preparation failed"; return 1; }

    print_message OK "Pre-setup process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?