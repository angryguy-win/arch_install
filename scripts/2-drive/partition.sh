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

# @description Setup LUKS encryption
# @arg $1 string Partition to encrypt
# @arg $2 string Mapper name
setup_luks() {
    local partition="$1"
    local mapper_name="$2"
    local password="$ENCRYPTION_PASSWORD"
    local commands=()

    if [[ -z "$password" ]]; then
        read -s -p "Enter LUKS encryption password: " password
        echo
    fi

    print_message INFO "Setting up LUKS encryption for $partition"
    commands+=("echo -n '$password' | cryptsetup luksFormat '$partition' -")
    commands+=("echo -n '$password' | cryptsetup open '$partition' '$mapper_name' -")

    execute_process "Setting Up LUKS" \
        --error-message "Failed to set up LUKS encryption" \
        --success-message "LUKS encryption set up successfully" \
        "${commands[@]}"
}
# @description Partition the device
# @arg $1 string Device to partition
# @arg $2 string Partition number
partition_device() {
    local device="$1"
    local number="$2"

    if [ -n "$INSTALL_DEVICE" ]; then
        case "$device" in 
        /dev/nvme* | /dev/mmcblk*)
            echo "${device}p${number}"  # For NVMe and eMMC devices
            ;;
        /dev/sd* | /dev/vd*)
            echo "${device}${number}"    # For SATA and Virtio devices
            ;;
        /dev/mapper/vg*-lv*)
            echo "/dev/mapper/vg0-lv${number}"  # For LVM logical volumes
            ;;
        *)
            print_message ERROR "Unknown device type: $device"  # Handle unknown device types
            return 1
            ;;
        esac
    else
        print_message ERROR "ERROR: The install device must be set in the configuration file."
        return 1
    fi
}
# @description Create the boot partitions
# @arg $1 string Device to partition
# @arg $2 string EFI size
# @arg $3 string Partition number
create_boot_partitions() {
    local device="$1"
    local efi_size="$2"
    local partition_number="$3"
    BOOT_PARTITIONS_CREATED=0
    local commands=()
    # Create the boot partitions based on BIOS type
    case "$BIOS_TYPE" in
        "bios")
            commands+=("sgdisk -n${partition_number}:2048:+1M -t${partition_number}:ef02 -c${partition_number}:'BIOSBOOT' $device")
            set_option "PARTITION_BIOSBOOT" "$(partition_device "$device" "$partition_number")"
            partition_number=$((partition_number + 1))
            commands+=("sgdisk -n${partition_number}:0:+1024M -t${partition_number}:8300 -c${partition_number}:'BOOT' $device")
            set_option "PARTITION_BOOT" "$(partition_device "$device" "$partition_number")"
            BOOT_PARTITIONS_CREATED=2
            ;;
        "uefi")
            commands+=("sgdisk -n${partition_number}:2048:\"$efi_size\" -t${partition_number}:ef00 -c${partition_number}:'EFIBOOT' $device")
            set_option "PARTITION_EFI" "$(partition_device "$device" "$partition_number")"
            BOOT_PARTITIONS_CREATED=1
            ;;
        "hybrid")
            commands+=("sgdisk -n${partition_number}:2048:+1M -t${partition_number}:ef02 -c${partition_number}:'BIOSBOOT' $device")
            set_option "PARTITION_BIOSBOOT" "$(partition_device "$device" "$partition_number")"
            partition_number=$((partition_number + 1))
            commands+=("sgdisk -n${partition_number}:0:\"$efi_size\" -t${partition_number}:ef00 -c${partition_number}:'EFIBOOT' $device")
            set_option "PARTITION_EFI" "$(partition_device "$device" "$partition_number")"
            BOOT_PARTITIONS_CREATED=2
            ;;
        *)
            print_message ERROR "Invalid BIOS type: $BIOS_TYPE"
            exit 1
            ;;
    esac
    # Execute the commands to create the boot partitions
    execute_process "Creating Boot Partitions" \
        --error-message "Failed to create boot partitions" \
        --success-message "Boot partitions created successfully" \
        "${commands[@]}"
}
# @description Create the swap partition
# @arg $1 string Device to partition
# @arg $2 string Swap size
# @arg $3 string Partition number
create_swap_partition() {
    local device="$1"
    local swap_size="$2"
    local partition_number="$3"
    local commands=()
    # 
    print_message ACTION "Creating Swap partition of size ${swap_size}"
    commands+=("sgdisk -n${partition_number}:0:${swap_size} -t${partition_number}:8200 -c${partition_number}:'SWAP' $device")
    set_option "PARTITION_SWAP" "$(partition_device "$device" "$partition_number")"

    execute_process "Creating Swap Partition" \
        --error-message "Failed to create swap partition" \
        --success-message "Swap partition created successfully" \
        "${commands[@]}"
}
# @description Create the root partition
# @arg $1 string Device to partition
# @arg $2 string Root size
# @arg $3 string Partition number
create_root_partition() {
    local device="$1"
    local size="$2"
    local partition_number="$3"
    local commands=()
    # Create the root partition
    print_message ACTION "Creating Root partition"
    local partition_type
    partition_type=$( [[ "$ENCRYPTION" == "true" ]] && echo "8309" || echo "8300" )
    commands+=("sgdisk -n${partition_number}:0:${size} -t${partition_number}:${partition_type} -c${partition_number}:'ROOT' $device")
    local root_partition
    root_partition="$(partition_device "$device" "$partition_number")"
    set_option "PARTITION_ROOT" "$root_partition"
    # If encryption is requested for root, setup LUKS
    if [[ "$ENCRYPTION" == "true" ]]; then
        setup_luks "$root_partition" "cryptroot"
        set_option "PARTITION_ROOT_ENC" "/dev/mapper/cryptroot"
    fi

    execute_process "Creating Root Partition" \
        --error-message "Failed to create root partition" \
        --success-message "Root partition created successfully" \
        "${commands[@]}"
}
# @description Create the home partition
# @arg $1 string Device to partition
# @arg $2 string Home size
# @arg $3 string Partition number
# @arg $4 string Home size
create_home_partition() {
    local device="$1"
    local size="$2"
    local partition_number="$3"
    local home_size="$4"
    local commands=()

    print_message ACTION "Creating Home partition of size ${home_size}G"
    local partition_type
    partition_type=$( [[ "$ENCRYPT_HOME" == "true" ]] && echo "8309" || echo "8300" )
    commands+=("sgdisk -n${partition_number}:0:${size} -t${partition_number}:${partition_type} -c${partition_number}:'HOME' $device")
    local home_partition
    home_partition="$(partition_device "$device" "$partition_number")"
    set_option "PARTITION_HOME" "$home_partition"
    if [[ "$ENCRYPT_HOME" == "true" ]]; then
        setup_luks "$home_partition" "crypthome"
        set_option "PARTITION_HOME_ENC" "/dev/mapper/crypthome"
    fi

    execute_process "Creating Home Partition" \
        --error-message "Failed to create home partition" \
        --success-message "Home partition created successfully" \
        "${commands[@]}"
}
# @description Partition the device
# @arg $1 string Device to partition    
partitioning() {
    local device="$1"
    local efi_size="+1024M"
    local swap_size="+${SWAP_SIZE:-4}G"
    local partition_number=1
    local commands=()
    local root_size

    print_message INFO "Install device set to: $device"

    # Unmount /mnt if mounted
    if mountpoint -q /mnt; then
        umount -A --recursive /mnt
        print_message INFO "Unmounting $device /mnt"
    else
        print_message ERROR "ERROR: Failed to unmount $device /mnt"
        return 1
    fi

    # Wipe GPT data and create new GPT partition table
    print_message ACTION "Wiping GPT and creating new partition table on $device"
    commands+=("sgdisk -Z $device")

    execute_process "Wiping GPT and creating new partition table" \
        --error-message "Failed to wipe GPT and create new partition table" \
        --success-message "Wiped GPT and created new partition table" \
        "${commands[@]}"

    # Create boot partitions based on BIOS type
    create_boot_partitions "$device" "$efi_size" "$partition_number"
    partition_number=$((partition_number + BOOT_PARTITIONS_CREATED))

    # Calculate remaining device size
    local device_size
    device_size=$(lsblk -b -dn -o SIZE "$device")
    device_size=$((device_size / 1024 / 1024 / 1024))  # Convert to GiB
    print_message INFO "Device size: $device_size GiB"
    local used_size=$((1024 * BOOT_PARTITIONS_CREATED / 1024))  # Approximate size used by boot partitions

    # Create swap partition if enabled
    if [[ "$SWAP" == "true" ]]; then
        create_swap_partition "$device" "$swap_size" "$partition_number"
        used_size=$((used_size + ${swap_size//+G/}))
        partition_number=$((partition_number + 1))
    fi

    # Create root and home partitions
    if [[ "$HOME" == "true" ]]; then
        create_root_partition "$device" "+32G" "$partition_number"
        used_size=$((used_size + 32))
        partition_number=$((partition_number + 1))

        home_size=$((device_size - used_size))
        create_home_partition "$device" "0" "$partition_number" "$home_size"
        partition_number=$((partition_number + 1))
    else
        root_size=$((device_size - used_size))
        create_root_partition "$device" "0" "$partition_number"
        partition_number=$((partition_number + 1))
    fi

    # Display the resulting partitions
    lsblk "${device}" || print_message WARNING "Failed to list partitions"
}
# @description Main function
main() {
    load_config
    process_init "Partitioning the install: $DEVICE"
    print_message INFO "Starting partition process on $DEVICE"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    #prepare_drive ${INSTALL_DEVICE} ${BIOS_TYPE} || { print_message ERROR "Drive preparation failed"; return 1; }
    partitioning "${DEVICE}" "${BIOS_TYPE}" || { print_message ERROR "Partitioning failed"; return 1; }

    print_message OK "Partition btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?