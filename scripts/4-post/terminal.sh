#!/bin/bash
# Terminal Script
# Author: ssnow
# Date: 2024
# Description: Terminal installation script for Arch Linux

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


terminal() {
    
    print_message INFO "Installing Terminal"
    execute_process "Installing Terminal" \
        --use-chroot \
        --error-message "Terminal installation failed" \
        --success-message "Terminal installation completed" \
        "pacman -S --noconfirm --needed ${TERMINAL} kitty ${SHELL} starship" \
        "cp -r ${SCRIPT_DIR}/config/${TERMINAL} ~/.config/${TERMINAL}" \
        "cp -r ${SCRIPT_DIR}/config/starship.toml ~/.config/starship.toml" \
        "cp -r ${SCRIPT_DIR}/config/${SHELL}rc ~/.${SHELL}rc"
}

main() {
    process_init "Terminal: $TERMINAL"
    print_message INFO "Starting Terminal process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    terminal || { print_message ERROR "Terminal installation failed"; return 1; }
    print_message OK "Terminal installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?