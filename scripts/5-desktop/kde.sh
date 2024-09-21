#!/bin/bash
# KDE Script
# Author: ssnow
# Date: 2024
# Description: KDE Plasma installation script for Arch Linux

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


kde_plasma() {
    
    print_message INFO "Installing KDE Plasma"
    execute_process "Installing KDE Plasma" \
        --error-message "KDE Plasma installation failed" \
        --success-message "KDE Plasma installation completed" \
        "pacman -S --noconfirm --needed plasma plasma-wayland-session kde-applications"

}

main() {
    process_init "KDE Plasma"
    show_logo "KDE Plasma"
    print_message INFO "Starting KDE Plasma process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    kde_plasma || { print_message ERROR "KDE Plasma installation failed"; return 1; }
    print_message OK "KDE Plasma installation completed successfully"
    process_end $?
}

# Run the main function
main "$@" | log_main "$PROCESS_LOG"
exit $?