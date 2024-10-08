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

export DRY_RUN="${DRY_RUN:-false}"

# @description Format boot partition
# @param $1 partition_boot
# @param $2 bios_type
boot_formatting() {
    local partition_boot="$1"
    local bios_type="$2"
    local command

    if [[ "$bios_type" == "uefi" ]]; then
        command="mkfs.vfat -F32 -n EFIBOOT $partition_boot"  # Format EFI boot partition
    elif [[ "$bios_type" == "bios" ]]; then
        command="mkfs.ext4 -L BOOT $partition_boot"  # Format BIOS boot partition
    fi

    execute_process "Formatting boot partition" \
        --error-message "Formatting boot partition failed" \
        --success-message "Boot partition formatted successfully" \
        "$command"
}

# @description Format root partition
# @param $1 partition_root
# @param $2 filesystem_type
root_formatting() {
    local partition_root="$1"
    local filesystem_type="$2"
    local command=()

    print_message ACTION "Formatting root partition on $partition_root"
    # Check if the partition exists
    if [[ ! -b "$partition_root" && "$DRY_RUN" == "false" ]]; then
        print_message ERROR "The specified root partition does not exist: $partition_root"
        return 1
    fi
    # If LUKS is enabled, format with LUKS encryption
    if [[ "$LUKS" == "true" ]]; then
        # Format LUKS partition
        print_message DEBUG "Formatting LUKS partition on $partition_root"
        command+=("cryptsetup luksFormat --type luks2 $partition_root")
        # Open LUKS partition
        print_message DEBUG "Opening LUKS partition on $partition_root"
        command+=("cryptsetup open $partition_root cryptroot")
        # Update to the mapped device
        command+=("$partition_root=/dev/mapper/cryptroot")
    fi

    # Format the root partition with the specified filesystem
    print_message ACTION "Formatting root partition with $filesystem_type"
    if [[ "$filesystem_type" == "ext4" || "$filesystem_type" == "btrfs" ]]; then
        command+=("mkfs.$filesystem_type -L ROOT $partition_root")
    else
        print_message ERROR "Unsupported filesystem type: $filesystem_type"
        return 1
    fi

    execute_process "Formatting root partition" \
        --error-message "Formatting root partition failed" \
        --success-message "Root partition formatted successfully" \
        "${command[@]}"
}

# @description Create subvolumes
create_subvolumes() {
    local partition_root="$1"
    local subvol
    local command=()
    local subvolumes=(${SUBVOLUMES//,/ })  # Convert to array, splitting by comma

    # Convert SUBVOLUMES to a space-separated string for POSIX compliance
    #subvolumes=$(echo "$SUBVOLUMES" | tr ',' ' ')  # Convert to space-separated

    print_message ACTION "Creating subvolumes on $partition_root"
    # Mount the root partition  
    print_message DEBUG "Mounted $partition_root to /mnt"
    command+=("mount -t btrfs $partition_root /mnt")
    # Create root subvolume
    print_message DEBUG "Creating subvolumes: ${SUBVOLUMES}"
    # Create subvolumes from the SUBVOLUME variable
    command+=("btrfs subvolume create /mnt/@")  # Create root subvolume 
    for subvol in "${subvolumes[@]}"; do
        command+=("btrfs subvolume create /mnt/$subvol")  # Create subvolume without @ prefix
    done
    
    print_message DEBUG "Umount the subvolumes"
    command+=("umount /mnt")

    execute_process "Umount the subvolumes" \
        --error-message "Failed to Unmount /mnt " \
        --success-message "Subvolume Unmounted /mnt successfully" \
        "${command[@]}"
}

# @description Format home partition if it exists
# @param $1 partition_home
home_formatting() {
    local partition_home="$1"
    local command=()

    if [[ -n "$partition_home" && "$FILE_SYSTEM_TYPE" == "btrfs" ]]; then
        print_message ACTION "Formatting home partition with btrfs"
        command+=("mkfs.btrfs -L HOME $partition_home")
    else
        print_message ACTION "Formatting home partition whit ext4"
        command+=("mkfs.ext4 -L HOME $partition_home")
    fi
    execute_process "Formatting home partition" \
        --error-message "Formatting home partition failed" \
        --success-message "Home partition formatted successfully" \
        "${command[@]}"

}

# @description Format swap partition if it exists
# @param $1 partition_swap
swap_formatting() {
    local partition_swap="$1"
    local command=()

    print_message ACTION "Formatting swap partition"
    command+=("mkswap -L SWAP $partition_swap")
    print_message DEBUG "Enabling swap on $partition_swap"
    command+=("swapon $partition_swap")

    execute_process "Enabling swap" \
        --error-message "Enabling swap failed" \
        --success-message "Swap enabled successfully" \
        "${command[@]}"
}

# @description Mount partitions and subvolumes
# @param $1 partition_boot
# @param $2 partition_root
# @param $3 partition_home
partition_mount() {
    local partition_boot="$1"
    local partition_root="$2"
    local partition_home="$3"
    local command=()
    IFS=',' read -ra subvolumes <<< "$SUBVOLUMES"  # Safely split into array
    #local subvolumes=(${SUBVOLUMES//,/ })  # Convert to array, splitting by comma if you add quotes it break this
    local subvol                           


    # Add this check for LUKS
    if [[ "$LUKS" == "true" ]]; then
        partition_root="/dev/mapper/cryptroot" # Set the root partition to the mapped device
    fi

    if [[ "$FILE_SYSTEM_TYPE" == "btrfs" ]]; then
        # Create necessary directories dynamically based on subvolumes
        print_message DEBUG "Creating directories: "
        for subvol in "${subvolumes[@]}"; do
            command+=("mkdir -p /mnt/$subvol")  # Create directories for subvolumes
        done
        command+=("mkdir -p /mnt/boot/efi")
        
        # Mount root subvolume without @ prefix
        print_message DEBUG "Mounted $partition_root to /mnt"
        command+=("mount -o $MOUNT_OPTIONS,subvol=@ $partition_root /mnt")
        # Mount each subvolume without @ prefix
        for subvol in "${subvolumes[@]}"; do
            command+=("mount -o $MOUNT_OPTIONS,subvol=$subvol $partition_root /mnt/$subvol")
        done
        
        print_message DEBUG "Mounting EFI boot partition"
        command+=("mount -t vfat -L EFIBOOT /mnt/boot/efi")

        # Mount home partition if it exists
        if [[ "$HOME" = true ]]; then
            print_message DEBUG "Mounting home partition"
            command+=("mkdir -p /mnt/home")
            command+=("mount -o $MOUNT_OPTIONS $partition_home /mnt/home")
        fi
    else
        print_message DEBUG "Mounting root partition to /mnt"
        command+=("mount -o ${MOUNT_OPTIONS} $partition_root /mnt")  # Mount root
        print_message DEBUG "Mounted $partition_boot to /mnt/boot"
        command+=("mkdir -p /mnt/boot")
        command+=("mount -o ${MOUNT_OPTIONS_BOOT} $partition_boot /mnt/boot")  # Mount boot

        # Mount home partition if it exists
        if [[ "$HOME" = true ]]; then
            print_message DEBUG "Mounting home partition"
            command+=("mkdir -p /mnt/home")
            command+=("mount -o ${MOUNT_OPTIONS} $partition_home /mnt/home")
        fi
    fi

    # Execute the commands
    execute_process "Enabling swap" \
        --error-message "Enabling swap failed" \
        --success-message "Swap enabled successfully" \
        "${command[@]}"
}

# @description Main function
main() {
    process_init "Formatting on $INSTALL_DEVICE whit ${FILE_SYSTEM_TYPE}"
    print_message INFO "Starting formatting partitions ${FILE_SYSTEM_TYPE} process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    if [[ "$LUKS" == "true" ]] && ! command -v cryptsetup &> /dev/null; then
        print_message ERROR "cryptsetup is not installed. It's required for LUKS encryption."
        return 1
    fi
    # Load config
    load_config || { print_message ERROR "Loading config failed"; return 1; }
    print_message DEBUG "The sublomuve are: ${SUBVOLUME}"
    # Format boot partition
    boot_formatting "$PARTITION_BOOT" "$BIOS_TYPE" || { print_message ERROR "Formatting boot partition failed"; return 1; }

    # Format root partition
    root_formatting "$PARTITION_ROOT" "$FILE_SYSTEM_TYPE" || { print_message ERROR "Formatting root partition failed"; return 1; }

    # Format home partition if it exists
    if [[ "$HOME" = true ]]; then
        home_formatting "$PARTITION_HOME" || { print_message ERROR "Formatting home partition failed"; return 1; }
    fi

    # Format swap partition if it exists    
    if [[ "$SWAP" = true ]]; then
        swap_formatting "$PARTITION_SWAP" || { print_message ERROR "Formatting swap partition failed"; return 1; }
    fi


    # Create subvolumes if using Btrfs
    if [[ "$FILE_SYSTEM_TYPE" = "btrfs" ]]; then
        create_subvolumes "$PARTITION_ROOT" || { print_message ERROR "Creating subvolumes failed"; return 1; }
    fi

    # Mount partitions and subvolumes
    partition_mount "$PARTITION_BOOT" "$PARTITION_ROOT" "$PARTITION_HOME" || { print_message ERROR "Mounting partitions failed"; return 1; }

    print_message OK "Formatting partitions ${FILE_SYSTEM_TYPE} process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?