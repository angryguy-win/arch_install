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
    local partition_root="$1"
    if [ "$LUKS" = "true" ]; then
        if ! cryptsetup status cryptroot &>/dev/null; then
            execute_process "Opening LUKS container" \
                --error-message "Failed to open LUKS container" \
                --success-message "LUKS container opened successfully" \
                "cryptsetup luksOpen $partition_root cryptroot"
        else
            print_message INFO "LUKS container already open"
        fi
        echo "/dev/mapper/cryptroot"
    else
        echo "$partition_root"
    fi
}

# @description Format partitions
# @param partition_root
# @param partition_efi
# @param bios_type
formating() {
    local partition_root="$1"
    local partition_efi="$2"
    local bios_type="$3"
    local partition_biosboot="$4"
    local commands=()

    # Handle boot partition formatting based on BIOS type
    case "$bios_type" in
        uefi|UEFI|hybrid)
            print_message DEBUG "Before Format EFIBOOT: $partition_efi as vfat"
            commands+=("mkfs.vfat -F32 -n EFIBOOT $partition_efi")
            ;;
        bios|BIOS)
            print_message DEBUG "Before Format BIOSBOOT: $partition_biosboot as ext4"
            commands+=("mkfs.ext4 -L BOOT $partition_biosboot")
            ;;
        *)
            print_message ERROR "Unsupported BIOS type: $bios_type"
            return 1
            ;;
    esac
    # Handle LUKS encryption if enabled
    if [ "$LUKS" = "true" ]; then
        print_message DEBUG "Setting up LUKS encryption on $partition_root"
        commands+=("cryptsetup luksFormat $partition_root")
        commands+=("cryptsetup luksOpen $partition_root cryptroot")
        partition_root="/dev/mapper/cryptroot"
    fi
    # Format root partition based on filesystem type
    case "$FORMAT_TYPE" in
        btrfs)
            print_message DEBUG "Before Format ROOT: $partition_root as btrfs"
            commands+=("mkfs.btrfs -f -L ROOT $partition_root")
            commands+=("mount -t btrfs $partition_root /mnt")
            ;;
        ext4)
            print_message DEBUG "Before Format ROOT: $partition_root as ext4"
            commands+=("mkfs.ext4 -L ROOT $partition_root")
            commands+=("mount $partition_root /mnt")
            ;;
        *)
            print_message ERROR "Unsupported filesystem type: $FORMAT_TYPE"
            return 1
            ;;
    esac

    execute_process "Formatting partitions" \
        --error-message "Formatting partitions failed" \
        --success-message "Formatting partitions completed" \
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
    if [ "$FORMAT_TYPE" = "btrfs" ]; then
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

    # LUKS setup
    partition_root=$(luks_setup "$partition_root")

    # Mounting based on filesystem type
    if [ "$FORMAT_TYPE" = "btrfs" ]; then
        commands+=("mount -o $mount_options,subvol=@ $partition_root /mnt")
        # Create all necessary directories
        for subvol in "${subvolumes[@]}"; do
            commands+=("mkdir -p /mnt/${subvol#@}")
        done
        # Loop through subvolumes and add mount commands
        for subvol in "${subvolumes[@]}"; do
            commands+=("mount -o $mount_options,subvol=$subvol $partition_root /mnt/${subvol#@}")
        done
    elif [ "$FORMAT_TYPE" = "ext4" ]; then
        commands+=("mount $partition_root /mnt")
    fi

    # Create and mount EFI partition
    commands+=("mkdir -p /mnt/boot/efi")
    commands+=("mount -t vfat -L EFIBOOT /mnt/boot/efi")

    # Execute the commands
    execute_process "Mounting partitions" \
        --error-message "Mounting partitions failed" \
        --success-message "Mounting partitions completed" \
        "${commands[@]}"
}
main() {
    #load_config
    process_init "Formatting partitions $FORMAT_TYPE"
    print_message INFO "Starting formatting partitions $FORMAT_TYPE process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    formating $PARTITION_ROOT $PARTITION_EFI $BIOS_TYPE $PARTITION_BIOSBOOT || { print_message ERROR "Formatting partitions btrfs failed"; return 1; }
    subvolumes_setup $PARTITION_ROOT || { print_message ERROR "Creating subvolumes failed"; return 1; }
    mounting $PARTITION_ROOT $MOUNT_OPTIONS|| { print_message ERROR "Mounting subvolumes btrfs failed"; return 1; }

    print_message OK "Formatting partitions btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?
