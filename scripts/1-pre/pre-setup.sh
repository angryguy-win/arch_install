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
# Initial setup
initial_setup() {
    print_message INFO "Starting initial setup"
    # Initial setup
    execute_process "Initial setup" \
        --debug \
        --error-message "Initial setup failed" \
        --success-message "Initial setup completed" \
        "timedatectl set-ntp true" \
        "pacman -Sy" \
        "pacman -S archlinux-keyring --noconfirm" \
        "pacman -S --noconfirm --needed pacman-contrib terminus-font reflector rsync grub" \
        "setfont ter-v22b" \
        "sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf" \
        "pacman -Syy"
}
# Mirror setup
mirror_setup() {
    local country_iso
    country_iso=$(curl -4 ifconfig.co/country-iso)
    
    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
        "reflector -a 48 -c ${country_iso} -f 5 -l 20 --save /etc/pacman.d/mirrorlist"

        set_option "COUNTRY_ISO" "$country_iso"
}
create_mnt() {
    local commands=""
    print_message ACTION "Installing prerequistes: "
    # Install prerequistes
    commands+="pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc"
    # make sure everything is unmounted before we start
    commands+="umount -A --recursive /mnt"

    execute_process "Creating /mnt and installing prerequistes" \
        --error-message "Creating /mnt and installing prerequistes failed" \
        --success-message "Creating /mnt and installing prerequistes completed" \
        "${commands[@]}"
}

main() {
    process_init "Pre-setup"
    print_message INFO "Starting pre-setup process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    initial_setup || { print_message ERROR "Initial setup failed"; return 1; }
    mirror_setup || { print_message ERROR "Mirror setup failed"; return 1; }
    create_mnt || { print_message ERROR "Mount failed"; return 1; }

    print_message OK "Pre-setup process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?