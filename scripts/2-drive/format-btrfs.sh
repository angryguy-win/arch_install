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
    local command
    # Convert SUBVOLUMES to an array
    local subvolumes=(${SUBVOLUMES//,/ }) # DO NOT "" it breaks the array
    local subvol
    
    # Create subvolumes from the SUBVOLUME variable
    if [ "$FILE_SYSTEM_TYPE" = "btrfs" ]; then
        print_message INFO "Mounting $partition_root and creating subvolumes"
        
        execute_process "Creating subvolumes" \
            --error-message "Failed to create subvolumes" \
            --success-message "Subvolumes created successfully" \
            "mount -t btrfs $partition_root /mnt" \
            "btrfs subvolume create /mnt/@" \
            "$(for subvol in "${subvolumes[@]}"; do echo "btrfs subvolume create /mnt/$subvol"; done)" \
            "umount /mnt"
    fi 
}
mounting() {
    local partition_root="$1"
    local mount_options="$2"
    local command=()
    local subvolumes=(${SUBVOLUMES//,/ })
    local subvol

    # Add the initial mount command
    command+=("mount -o \"$mount_options,subvol=@\" \"$partition_root\" \"/mnt\"")

    # Add the directory creation command
    command+=("mkdir -p \"/mnt/{home,var,tmp,.snapshots,boot/efi}\"")

    # Loop through subvolumes and add mount commands
    for subvol in "${subvolumes[@]}"; do
        command+=("mount -o \"$mount_options,subvol=$subvol\" \"$partition_root\" \"/mnt/$subvol\"")
    done

    # Add the EFI boot mount command
    command+=("mount -t vfat -L EFIBOOT \"/mnt/boot/efi\"")

    # Debugging: Print the commands to be executed
    for cmd in "${command[@]}"; do
        print_message DEBUG "Command to execute: $cmd"
    done

    # Execute the commands
    execute_process "Mounting subvolumes btrfs" \
        --error-message "Mounting subvolumes btrfs failed" \
        --success-message "Mounting subvolumes btrfs completed" \
        "${command[@]}"
}
main() {
    load_config
    process_init "Formatting partitions $FORMAT_TYPE"
    print_message INFO "Starting formatting partitions $FORMAT_TYPE process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    formating || { print_message ERROR "Formatting partitions btrfs failed"; return 1; }
    subvolumes_setup $PARTITION_ROOT || { print_message ERROR "Creating subvolumes failed"; return 1; }
    mounting $PARTITION_ROOT $MOUNT_OPTIONS|| { print_message ERROR "Mounting subvolumes btrfs failed"; return 1; }

    print_message OK "Formatting partitions btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?