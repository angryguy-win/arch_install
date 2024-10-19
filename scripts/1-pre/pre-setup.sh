#!/bin/bash
# Pre-setup Script
# Author: ssnow
# Date: 2024
# Description: Pre-setup script for Arch Linux installation

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

set -o errtrace
set -o functrace
set_error_trap

# Get the current stage/script context
get_current_context

# Function to set partition tools based on conditions
set_tools() {
    [ "$LUKS" = "true" ] && tools+=("cryptsetup")
    [[ "$BIOS_TYPE" =~ ^(uefi|UEFI|hybrid)$ ]] && tools+=("efibootmgr")
    
    case "$FORMAT_TYPE" in
            btrfs) tools+=("btrfs-progs") ;;
            ext4)  tools+=("e2fsprogs") ;;
            *)     print_message ERROR "Invalid FORMAT_TYPE: $FORMAT_TYPE"; return 1 ;;
    esac

        # Add e2fsprogs for BIOS if not already added for ext4
    if [[ ! "$BIOS_TYPE" =~ ^(uefi|UEFI|hybrid)$ ]] && [[ "$FORMAT_TYPE" != "ext4" ]]; then
        tools+=("e2fsprogs")
    fi

    # Remove duplicates
    mapfile -t tools < <(printf '%s\n' "${tools[@]}" | sort -u)
}

initial_setup() {
    local tools=()

    print_message INFO "Starting initial setup"
    set_tools || return 1

    # Initial setup
    execute_process "Initial setup" \
        --debug \
        --error-message "Initial setup failed" \
        --success-message "Initial setup completed" \
        --checkpoint-step "1-pre" "$CURRENT_SCRIPT" "initial_setup" \
        "timedatectl set-ntp true" \
        "pacman -Sy archlinux-keyring --noconfirm" \
        "pacman -S --noconfirm --needed pacman-contrib terminus-font rsync reflector gptfdisk ${tools[*]}" \
        "setfont ter-v22b" \
        "sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf" \
        "pacman -Syy"
}
mirror_setup() {
    local country_iso="$1"
    curl -4 'https://ifconfig.co/country-iso' > "$country_iso"
    selected_drive=$(sanitize "$selected_drive")

    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        --checkpoint-step "1-pre" "$CURRENT_SCRIPT" "mirror_setup" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup" \
        "reflector -c $country_iso -c US -a 12 -p https -f 5 -l 10 --sort rate --save /etc/pacman.d/mirrorlist"

}

main() {
    save_checkpoint "$CURRENT_STAGE" "$CURRENT_SCRIPT" "main" "0"
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
