#!/bin/bash
# System Config Script
# Author: ssnow
# Date: 2024
# Description: System config script for Arch Linux installation

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


system_config() {

    print_message DEBUG "Chroot operations: $HOSTNAME, $LOCALE, $TIMEZONE, $KEYMAP, $USERNAME, $PASSWORD"
    execute_process "System config" \
        --use-chroot \
        --error-message "System config failed" \
        --success-message "System config completed" \
        "echo '$HOSTNAME' > /etc/hostname" \
        "echo '$LOCALE UTF-8' > /etc/locale.gen" \
        "locale-gen" \
        "echo 'LANG=$LOCALE' > /etc/locale.conf" \
        "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime" \
        "echo 'KEYMAP=$KEYMAP' > /etc/vconsole.conf" \
        "useradd -m -G wheel -s /bin/bash $USERNAME" \
        "echo 'root:$PASSWORD' | chpasswd" \
        "echo '$USERNAME:$PASSWORD' | chpasswd" \
        "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers"

}

main() {
    process_init "System Config"
    show_logo "System Config"
    print_message INFO "Starting system config process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    system_config || { print_message ERROR "System config process failed"; return 1; }

    print_message OK "System config process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?