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
    local partition_tools=""
    local encryption_tools=""
    local uefi_tools=""
    local bios_tools=""
    if [ "$LUKS" = "true" ]; then
        encryption_tools="cryptsetup"
    fi
    if [ "$BIOS_TYPE" = "uefi|UEFI" ]; then
        uefi_tools="efibootmgr"
    else
        bios_tools="e2fsprogs"
    fi
    print_message INFO "Starting initial setup"
    case "$FORMAT_TYPE" in
        btrfs)
            partition_tools="btrfs-progs"
            ;;
        ext4)
            partition_tools="e2fsprogs"
            ;;
        *)
            print_message ERROR "Invalid FORMAT_TYPE: $FORMAT_TYPE"
            return 1
            ;;
    esac

    # Initial setup
    execute_process "Initial setup" \
        --debug \
        --error-message "Initial setup failed" \
        --success-message "Initial setup completed" \
        "timedatectl set-ntp true" \
        "pacman -Sy archlinux-keyring --noconfirm" \
        "pacman -S --noconfirm --needed pacman-contrib terminus-font rsync reflector gptfdisk $partition_tools $encryption_tools $uefi_tools $bios_tools" \
        "setfont ter-v22b" \
        "sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf" \
        "pacman -Syy"
}
mirror_setup() {
    local country_iso="$1"
    curl -4 'https://ifconfig.co/country-iso' > $country_iso

    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
        "reflector -c $country_iso -c US -a 12 -p https -f 5 -l 10 --sort rate --save /etc/pacman.d/mirrorlist"

}

main() {
    process_init "Pre-setup"
    print_message INFO "Starting pre-setup process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    initial_setup || { print_message ERROR "Initial setup failed"; return 1; }
    mirror_setup "$COUNTRY_ISO" || { print_message ERROR "Mirror setup failed"; return 1; }

    print_message OK "Pre-setup process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?