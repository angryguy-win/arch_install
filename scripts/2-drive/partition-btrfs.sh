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

export DRY_RUN="${DRY_RUN:-false}"

# @description Partition device
# @param $1 device
# @param $2 number
partition_device() {
    local device="$1"
    local number="$2"
    # Check if the device is a NVMe or mmcblk device
    if [[ "$device" =~ ^/dev/(nvme|mmcblk) ]]; then
        echo "${device}p${number}"
    else
        echo "${device}${number}"
    fi
}

# @description Partitioning
# @param $1 device
# @param $2 number
partitioning() {
    local command=()  # Declare command as an array
    local partition_number
    local total_size
    local remaining_size
    local boot_size="+1G"  # Boot partition size
    local swap_size="+${SWAP_SIZE:-4}G"
    local root_size
    local home_size
    local device_size

    print_message INFO "Install device set to: $DEVICE"

    # Initialize partition commands
    print_message ACTION "Wiping the partition table on $DEVICE"
    command+=("sgdisk -Z $DEVICE")
    #command+=("sgdisk -o $DEVICE")
    #command+=("wipefs -a -f $DEVICE")
    #command+=("partprobe -s $DEVICE")

    print_message ACTION "Calculating partition sizes"
    # Get the total size of the device in GiB
    device_size=$(lsblk -b -dn -o SIZE "$DEVICE")
    device_size=$((device_size / 1024 / 1024 / 1024))  # Convert to GiB
    print_message INFO "Device size: $device_size GiB"
    # Subtract boot partition size
    remaining_size=$((device_size - 1))  # Subtract 1 GiB for boot

    # Calculate swap size
    if [[ "$SWAP" == "true" ]]; then
        swap_size="+${SWAP_SIZE}G"  # Swap partition size
        remaining_size=$((remaining_size - $swap_size))
        print_message ACTION "Creating Swap partition size: $swap_size"
    fi

    # Calculate root size
    if [[ "$HOME" == "true" ]]; then
        root_size="+32G"  # Minimum root partition size
        remaining_size=$((remaining_size - root_size))
        print_message ACTION "Creating Home partition size: $remaining_size"
        if (( remaining_size < 0 )); then
            print_message ERROR "Not enough space for root and swap partitions."
            exit 1
        fi
        home_size=      # Will calculate after assigning root size
    else
        root_size=""    # Use remaining space
    fi

    print_message ACTION "Partitioning $DEVICE $BIOS_TYPE drive"
    # Partition the disk
    if [[ "$BIOS_TYPE" == "uefi" ]]; then
        command+=("sgdisk -n1:0:$boot_size -t1:ef00 -c1:EFI_BOOT ${DEVICE}")  # EFI partition
    else
        command+=("sgdisk -a1 -n1:24K:+1000K -t1:ef02 -c1:BIOSBOOT ${DEVICE}")  # BIOS boot partition
    fi
    print_message ACTION "BOOT $BIOS_TYPE partition: $boot_size on $DEVICE 1"
    set_option PARTITION_BOOT "$(partition_device "$DEVICE" 1)"
    print_message DEBUG "Setting: BOOT partition: on $PARTITION_BOOT"
    partition_number=2

    # Create swap partition if enabled
    if [[ "$SWAP" == "true" ]]; then
        print_message ACTION "Creating swap partition"
        command+=("sgdisk -n${partition_number}:0:${swap_size} -t${partition_number}:8200 -c${partition_number}:SWAP ${DEVICE}")
        print_message DEBUG "Swap partition: $swap_size on $DEVICE $partition_number" 
        set_option PARTITION_SWAP "$(partition_device "$DEVICE" $partition_number)"
        print_message DEBUG "Setting: SWAP partition: on $PARTITION_SWAP"
        partition_number=$((partition_number + 1))
    fi

    # Create root partition
    print_message ACTION "Creating root partition"
    if [[ -n "$root_size" ]]; then
        command+=("sgdisk -n${partition_number}:0:${root_size} -t${partition_number}:8300 -c${partition_number}:ROOT ${DEVICE}")
    else
        command+=("sgdisk -n${partition_number}:0:0 -t${partition_number}:8300 -c${partition_number}:ROOT ${DEVICE}")
    fi
    print_message DEBUG "Root partition: $root_size on $DEVICE $partition_number"
    set_option PARTITION_ROOT "$(partition_device "$DEVICE" $partition_number)"
    print_message DEBUG "Setting: ROOT partition: on $PARTITION_ROOT"
    partition_number=$((partition_number + 1))

    # Create home partition if enabled
    if [[ "$HOME" == "true" ]]; then
        home_size=""  # Use remaining space
        command+=("sgdisk -n${partition_number}:0:0 -t${partition_number}:8300 -c${partition_number}:HOME ${DEVICE}")
        set_option PARTITION_HOME "$(partition_device "$DEVICE" $partition_number)"
        print_message ACTION "Creating Home partition"
        print_message DEBUG "Home partition: on $PARTITION_HOME"
        partition_number=$((partition_number + 1))
    fi

    command+=("partprobe -s $DEVICE")
    print_message DEBUG "Informing OS of partition table changes on $DEVICE (partprobe)"

    execute_process "Partitioning the install $DEVICE" \
        --error-message "Partition failed" \
        --success-message "Partitioning completed successfully" \
        "${command[@]}"


    print_message INFO "Partitions created:"
    lsblk "$DEVICE"
}

main() {
    process_init "Partition the install device: $INSTALL_DEVICE"
    print_message INFO "Starting partition process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"
    load_config || { print_message ERROR "Failed to load config"; return 1; }

    print_message DEBUG "Starting partitioning process"
    partitioning || { print_message ERROR "Partitioning failed"; return 1; }

    print_message OK "Partition btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?