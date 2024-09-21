#!/bin/bash
# Bootstrap Packages Script
# Author: ssnow
# Date: 2024
# Description: Bootstrap packages script for Arch Linux installation

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

set_microcode() {

    local microcode
    microcode=$(determine_microcode)
    if [ -n "$MICROCODE" ]; then
        print_message DEBUG "Microcode set to: ${MICROCODE}"
    else
        print_message WARNING "Microcode not set using probe: "
        print_message ACTION "Setting MICROCODE to: ${microcode}"
        export MICROCODE=$microcode
    fi

}       

bootstrap_pkgs() {

    print_message DEBUG "Bootstraping microcode: ${MICROCODE}"
    execute_process "Installing base system" \
        --error-message "Base system installation failed" \
        --success-message "Base system installation completed" \
        "pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub ${MICROCODE}-ucode --noconfirm --needed"

}

main() {
    process_init "Bootstrap Packages"
    show_logo "Bootstrap Packages"
    print_message INFO "Starting bootstrap packages process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    set_microcode || { print_message ERROR "Setting microcode failed"; return 1; }  
    bootstrap_pkgs || { print_message ERROR "Bootstrap packages process failed"; return 1; }

    print_message OK "Bootstrap packages process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?