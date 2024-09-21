#!/bin/bash
# Gnome Script
# Author: ssnow
# Date: 2024
# Description: Gnome OS installation script for Arch Linux

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


gnome_os() {
    
    print_message INFO "Installing Gnome OS"
    execute_process "Installing Gnome OS" \
        --error-message "Gnome OS installation failed" \
        --success-message "Gnome OS installation completed" \
        "pacman -S --noconfirm --needed gnome gnome-tweaks gdm"

}

main() {
    process_init "Gnome OS"
    show_logo "Gnome OS"
    print_message INFO "Starting gnome OS process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    gnome_os || { print_message ERROR "Gnome OS installation failed"; return 1; }
    print_message OK "Gnome OS installation completed successfully"
    process_end $?
}

# Run the main function
main "$@" | log_main "$PROCESS_LOG"
exit $?