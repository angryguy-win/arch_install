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
# @description Format partitions
# @param partition_root
# @param partition_efi
# @param bios_type
formating() {
    local partition_root="$1"
    local partition_efi="$2"
    local bios_type="$3"
    local commands=()

    print_message DEBUG "Before Format ROOT: $PARTITION_ROOT as btrfs"
    print_message DEBUG "Before Format EFIBOOT: $PARTITION_EFI as vfat"

    if [[ "$bios_type" == "uefi" ]]; then
        commands+=("mkfs.vfat -F32 -n EFIBOOT $partition_efi")  # Format EFI boot partition
    elif [[ "$bios_type" == "bios" ]]; then
        commands+=("mkfs.ext4 -L BOOT $partition_biosboot")  # Format BIOS boot partition
    fi
    commands+=("mkfs.btrfs -f -L ROOT $partition_root")
    commands+=("mount -t btrfs $partition_root /mnt")

    execute_process "Formatting partitions btrfs" \
        --error-message "Formatting partitions btrfs failed" \
        --success-message "Formatting partitions btrfs completed" \
        --critical \
        "${commands[@]}"
    
}
subvolumes_setup() {
    local partition_root="$1"
    # Convert SUBVOLUMES to an array
    local subvolumes=(${SUBVOLUMES//,/ }) # DO NOT "" it breaks the array
    local subvol
    
    # this is to show different methods of using the execute_process function.
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
    local commands=()
    local subvolumes=(${SUBVOLUMES//,/ })

    # This method of using execute_process needed to be modified to process 
    # multiple and single line commands. for this to work.
    # Add the initial mount command
    commands+=("mount -o $mount_options,subvol=@ $partition_root /mnt")

    # Create all necessary directories
    for subvol in "${subvolumes[@]}"; do
        commands+=("mkdir -p /mnt/${subvol#@}")
    done
    commands+=("mkdir -p /mnt/boot/efi")
    # Loop through subvolumes and add mount commands
    for subvol in "${subvolumes[@]}"; do
        commands+=("mount -o $mount_options,subvol=$subvol $partition_root /mnt/${subvol#@}")
    done

    # Add the EFI boot mount command
    commands+=("mount -t vfat -L EFIBOOT /mnt/boot/efi")

    # Execute the commands
    execute_process "Mounting subvolumes btrfs" \
        --error-message "Mounting subvolumes btrfs failed" \
        --success-message "Mounting subvolumes btrfs completed" \
        "${commands[@]}"
}
main() {
    logs
    #load_config
    process_init "Formatting partitions $FORMAT_TYPE"
    print_message INFO "Starting formatting partitions $FORMAT_TYPE process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    formating $PARTITION_ROOT $PARTITION_EFI $BIOS_TYPE || { print_message ERROR "Formatting partitions btrfs failed"; return 1; }
    subvolumes_setup $PARTITION_ROOT || { print_message ERROR "Creating subvolumes failed"; return 1; }
    mounting $PARTITION_ROOT $MOUNT_OPTIONS|| { print_message ERROR "Mounting subvolumes btrfs failed"; return 1; }

    print_message OK "Formatting partitions btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?
