#!/bin/bash
# Format Btrfs Script
# Author: ssnow
# Date: 2024
# Description: Format Btrfs script for Arch Linux installation

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


luks_setup() {
    print_message INFO "Setting up LUKS"

}
formating() {

    print_message DEBUG "Before Format ROOT: $PARTITION_ROOT as btrfs"
    print_message DEBUG "Before Format EFIBOOT: $PARTITION_EFI as vfat"

    execute_process "Formatting partitions btrfs" \
        --error-message "Formatting partitions btrfs failed" \
        --success-message "Formatting partitions btrfs completed" \
        --critical \
        "mkfs.vfat -F32 -n EFIBOOT $PARTITION_EFI" \
        "mkfs.btrfs -f -L ROOT $PARTITION_ROOT" \
        "mount -t btrfs $PARTITION_ROOT /mnt" 
    
}
subvolumes_setup() {
    local partition_root="$1"
    local command=()
    # Convert SUBVOLUMES to an array
    local subvolumes=(${SUBVOLUMES//,/ }) # DO NOT "" it breaks the array
    local subvol

    # Check if the file system type is btrfs
    if [[ "$FILE_SYSTEM_TYPE" == "btrfs" ]]; then
        # Mount the root partition
        print_message INFO "Mounting $partition_root and creating subvolumes"
        command+=("mount -t btrfs $partition_root /mnt")

        # Create subvolumes from the SUBVOLUME variable
        for subvol in "${subvolumes[@]}"; do
            print_message ACTION "Creating subvolume $subvol"
            command+=("btrfs subvolume create /mnt/$subvol")
        done
        # Unmount the subvolumes
        print_message ACTION "Unmounting /mnt"
        command+=("umount /mnt")
        # Execute the command
        execute_process "Creating subvolumes" \
            --error-message "Failed to create subvolumes" \
            --success-message "Subvolume created successfully" \
            "${command[@]}"
    fi 
}
mounting() {

    execute_process "Mounting subvolumes btrfs" \
        --error-message "Mounting subvolumes btrfs failed" \
        --success-message "Mounting subvolumes btrfs completed" \
        "mount -o $MOUNT_OPTIONS,subvol=@ $PARTITION_ROOT /mnt" \
        "mkdir -p /mnt/{home,var,tmp,.snapshots,boot/efi}" \
        "mount -o $MOUNT_OPTIONS,subvol=@home $PARTITION_ROOT /mnt/home" \
        "mount -o $MOUNT_OPTIONS,subvol=@tmp $PARTITION_ROOT /mnt/tmp" \
        "mount -o $MOUNT_OPTIONS,subvol=@var $PARTITION_ROOT /mnt/var" \
        "mount -o $MOUNT_OPTIONS,subvol=@.snapshots $PARTITION_ROOT /mnt/.snapshots" \
        "mount -t vfat -L EFIBOOT /mnt/boot/efi"

}
main() {
    process_init "Formatting partitions $FORMAT_TYPE"
    print_message INFO "Starting formatting partitions $FORMAT_TYPE process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    formating || { print_message ERROR "Formatting partitions btrfs failed"; return 1; }
    subvolumes_setup $PARTITION_ROOT || { print_message ERROR "Creating subvolumes failed"; return 1; }
    mounting || { print_message ERROR "Mounting subvolumes btrfs failed"; return 1; }

    print_message OK "Formatting partitions btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?