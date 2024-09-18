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
    
    print_message OK "Pre-setup process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?