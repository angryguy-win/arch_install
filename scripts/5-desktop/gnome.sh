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
set -o errtrace
set -o functrace
set_error_trap
# Get the current stage/script context
get_current_context
# Enable dry run mode for testing purposes (set to false to disable)
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"


gnome_os() {
    
    print_message INFO "Installing Gnome OS"
    execute_process "Installing Gnome OS" \
        --error-message "Gnome OS installation failed" \
        --success-message "Gnome OS installation completed" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "gnome_os" \
        "pacman -S --noconfirm --needed gnome gnome-tweaks gdm"

}

main() {
    save_checkpoint "$CURRENT_STAGE" "$CURRENT_SCRIPT" "main" "0"
    process_init "Installing: Gnome OS"
    print_message INFO "Starting gnome OS process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    gnome_os || { print_message ERROR "Gnome OS installation failed"; return 1; }
    print_message OK "Gnome OS installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?