#!/bin/bash
# Partition Btrfs Script
# Author: ssnow
# Date: 2024
# Description: Partition Btrfs script for Arch Linux installation

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


partitioning() {
    local device
    device="$1"

    execute_process "Partitioning" \
        --error-message "Partitioning failed" \
        --success-message "Partitioning completed" \
        "if mountpoint -q /mnt; then umount -A --recursive /mnt; else echo '/mnt is not mounted'; fi" \
        "sgdisk -Z $DEVICE" \
        "sgdisk -n1:0:+1M -t1:ef02 -c1:'BIOSBOOT' $DEVICE" \
        "sgdisk -n2:0:+512M -t2:ef00 -c2:'EFIBOOT' $DEVICE" \
        "sgdisk -n3:0:0 -t3:8300 -c3:'ROOT' $DEVICE"

}
luks_setup() {
    print_message INFO "Setting up LUKS"

}
main() {
    process_init "Partition Btrfs"
    show_logo "Partition Btrfs"
    print_message INFO "Starting partition btrfs process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    # Load configuration
    local vars=(install_device)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    partitioning ${install_device} || { print_message ERROR "Partitioning failed"; return 1; }

    print_message OK "Partition btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?