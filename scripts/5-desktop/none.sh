#!/bin/bash
# None Script
# Author: ssnow
# Date: 2024
# Description: None script for Arch Linux installation

set -e
trap 'exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

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

none() {
    
    print_message INFO "Installing basics no Desktop Environment"
    execute_process "Installing basics no Desktop Environment" \
        --error-message "basic'\s no Desktop Environment installation failed" \
        --success-message "Basics no Desktop Environment installation completed" \
        "pacman -S --noconfirm --needed openssh"

}
main() {
    process_init "Installing: no Desktop Environment"
    print_message INFO "Starting none process"

    none || { print_message ERROR "None process failed"; return 1; }

    print_message OK "None process completed successfully"
    process_end $?
}

main "$@"
exit $?