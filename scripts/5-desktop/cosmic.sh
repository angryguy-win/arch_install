#!/bin/bash
# Cosmic Script
# Author: ssnow
# Date: 2024
# Description: Cosmic OS installation script for Arch Linux

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


cosmic_os() {
    
    print_message INFO "Installing Cosmic OS"
    execute_process "Installing Cosmic OS" \
        --error-message "Cosmic OS installation failed" \
        --success-message "Cosmic OS installation completed" \
        "pacman -S --noconfirm --needed cosmic cosmic-greeter"

}

main() {
    process_init "Cosmic OS"
    show_logo "Cosmic OS"
    print_message INFO "Starting cosmic OS process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    cosmic_os || { print_message ERROR "Cosmic OS installation failed"; return 1; }
    print_message OK "Cosmic OS installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?