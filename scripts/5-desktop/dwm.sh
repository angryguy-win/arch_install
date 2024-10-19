#!/bin/bash
# DWM Script
# Author: ssnow
# Date: 2024
# Description: DWM installation script for Arch Linux

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

dwm() {
    
    print_message INFO "Installing DWM"
    execute_process "Installing DWM" \
        --error-message "DWM installation failed" \
        --success-message "DWM installation completed" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "dwm" \
        "pacman -S --noconfirm --needed dwm"

}

main() {
    save_checkpoint "$CURRENT_STAGE" "$CURRENT_SCRIPT" "main" "0"
    process_init "Installing: DWM"
    print_message INFO "Starting DWM process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    dwm || { print_message ERROR "DWM installation failed"; return 1; }
    print_message OK "DWM installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?