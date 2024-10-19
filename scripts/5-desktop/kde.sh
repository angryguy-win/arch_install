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
set -o errtrace
set -o functrace
set_error_trap
# Get the current stage/script context
get_current_context
# Enable dry run mode for testing purposes (set to false to disable)
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"


kde_plasma() {
    
    print_message INFO "Installing KDE Plasma"
    execute_process "Installing KDE Plasma" \
        --error-message "KDE Plasma installation failed" \
        --success-message "KDE Plasma installation completed" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "kde_plasma" \
        "pacman -S --noconfirm --needed plasma plasma-wayland-session kde-applications"

}

main() {
    save_checkpoint "$CURRENT_STAGE" "$CURRENT_SCRIPT" "main" "0"
    process_init "Installing: KDE Plasma"
    print_message INFO "Starting KDE Plasma process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    kde_plasma || { print_message ERROR "KDE Plasma installation failed"; return 1; }
    print_message OK "KDE Plasma installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?