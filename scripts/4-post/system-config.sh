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
if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Enable dry run mode for testing purposes (set to false to disable)
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"


system_config() {

    local hostname
    local locale
    local timezone
    local keymap
    local username
    local password

    hostname="$1"
    locale="$2" 
    timezone="$3"
    keymap="$4"
    username="$5"
    password="$6"

    print_message INFO "Chroot operations"
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

    # Load configuration
    local vars=(hostname locale timezone keymap username password)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    system_config ${hostname} ${locale} ${timezone} ${keymap} ${username} ${password} || { print_message ERROR "System config process failed"; return 1; }

    print_message OK "System config process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?