#!/bin/bash
# Last Cleanup Script
# Author: ssnow
# Date: 2024
# Description: Last cleanup script for Arch Linux

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


enable_services() {
    local display_message="$DISPLAY_MANAGER"
    local commands=()


    commands+=("systemctl enable NetworkManager")
    commands+=("systemctl enable sshd")
    commands+=("systemctl enable cronie")
    commands+=("systemctl enable bluetooth")
    commands+=("systemctl enable acpid")
    commands+=("systemctl enable ${display_message}")
    if [ "$DEVICE_TRIM" == "true" ]; then
        commands+=("systemctl enable fstrim.timer")
    fi
    if [ "$SNAPSHOTS" == "true" ]; then
        commands+=("systemctl enable btrfs-scrub@-.timer")
    fi
    print_message INFO "Enable and start services"
    execute_process "Enable and start services" \
        --use-chroot \
        --error-message "Enable and start services failed" \
        --success-message "Enable and start services completed" \
        "${commands[@]}"

}
swap() {
    if [ -n "$SWAP_SIZE" ] && [ "$SWAP" == "true" ]; then
        print_message INFO "Enable swap configuration"
        echo "vm.swappiness=10" > "${MNT_DIR}"/etc/sysctl.d/99-sysctl.conf
    fi
}

last_cleanup() {
    print_message INFO "Last cleanup"
    execute_process "Last cleanup" \
        --use-chroot \
        --error-message "Last cleanup failed" \
        --success-message "Last cleanup completed" \
        ""
        # TODO: Add a command to remove the installation media
        # TODO: Copy logs to /home/logs
        # TODO: copy config files to /home/config
}

main() {
    process_init "Last cleanup"
    print_message INFO "Starting last cleanup process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    enable_services || { print_message ERROR "Enable and start services failed"; return 1; }
    last_cleanup || { print_message ERROR "Last cleanup failed"; return 1; }
    swap || { print_message ERROR "Swap failed"; return 1; }

    print_message OK "Last cleanup completed successfully"
    print_message OK "Arch Linux installation completed. You can now reboot into your new system."
    process_end $?
}

# Run the main function
main "$@"
exit $?