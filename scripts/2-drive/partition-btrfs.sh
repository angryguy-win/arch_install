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
partitioning() {
    local device="$1"
    local efi_size="+1024M"
    local swap_size
    local root_size
    local home_size
    local remaining_size
    local partition_number="1"
    local commands=()

    print_message INFO "Install device set to: $device"
    print_message DEBUG "Checking if /mnt is mounted and unmounting it"
    commands+=("if mountpoint -q /mnt; then umount -A --recursive /mnt; else echo '/mnt is not mounted'; fi")
    print_message DEBUG "Wiping GPT data and setting new GPT partition"
    commands+=("sgdisk -Z ${device}")
    commands+=("sgdisk -a 2048 -o ${device}") # GPT offset

    print_message DEBUG "Formatting partitions $device: bios type $BIOS_TYPE"
    print_message DEBUG "Home partition: $HOME"
    print_message DEBUG "Swap partition: $SWAP"

    case $BIOS_TYPE in
        "bios")
            commands+=("sgdisk -n1:0:+1M -t1:ef02 -c1:'BIOSBOOT' ${device}") 
            set_option "PARTITION_BOOT" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))
            print_message DEBUG "Partition number: ${partition_number}, $device, BIOSBOOT: +1M"
            ;;
        "uefi")
            commands+=("sgdisk -n${partition_number}:0:${efi_size} -t${partition_number}:ef00 -c${partition_number}:'EFIBOOT' ${device}") 
            set_option "PARTITION_EFI" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))
            print_message DEBUG "Partition number: ${partition_number}, $device, EFI: $efi_size"
            ;;
        "hybrid")
            commands+=("sgdisk -n1:0:+1M -t1:ef02 -c1:'BIOSBOOT' ${device}") 
            set_option "PARTITION_BOOT" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))
            print_message DEBUG "Partition number: ${partition_number}, $device, BIOSBOOT: +1M"
            commands+=("sgdisk -n${partition_number}:0:${efi_size} -t${partition_number}:ef00 -c${partition_number}:'EFIBOOT' ${device}") 
            set_option "PARTITION_EFI" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))
            print_message DEBUG "Partition number: ${partition_number}, $device, EFI: $efi_size"
            ;;
        *)
            print_message ERROR "Invalid BIOS type: $BIOS_TYPE"
            return 1
            ;;
    esac

    print_message ACTION "Calculating partition sizes"
    device_size=$(lsblk -b -dn -o SIZE "$device")
    if [ $? -ne 0 ]; then
        print_message ERROR "Failed to get device size"
        return 1
    fi
    device_size=$((device_size / 1024 / 1024 / 1024))  # Convert to GiB
    print_message INFO "Device size: $device_size GiB"
    remaining_size=$((device_size - 2))  # Subtract 2 GiB for boot/EFI

    if [[ "$SWAP" == "true" ]]; then
        swap_size=$SWAP_SIZE
        if ((remaining_size < swap_size)); then
            print_message ERROR "Not enough space for swap partition"
            return 1
        fi
        remaining_size=$((remaining_size - swap_size))
        print_message ACTION "Creating Swap partition size: ${swap_size}G"
        commands+=("sgdisk -n${partition_number}:0:+${swap_size}G -t${partition_number}:8200 -c${partition_number}:'SWAP' ${device}") 
        set_option "PARTITION_SWAP" "$(partition_device "${device}" "${partition_number}")"
        print_message DEBUG "Partition number: ${partition_number}, $device, SWAP: ${swap_size}G"
        partition_number=$((partition_number + 1))
    fi

    if [[ "$HOME" == "true" ]]; then
        root_size=32  # 32 GiB for root when separate home
        if ((remaining_size < root_size)); then
            print_message ERROR "Not enough space for root partition"
            return 1
        fi
        remaining_size=$((remaining_size - root_size))
        home_size=$remaining_size

        print_message ACTION "Creating Root partition size: ${root_size}G"
        commands+=("sgdisk -n${partition_number}:0:+${root_size}G -t${partition_number}:8300 -c${partition_number}:'ROOT' ${device}") 
        set_option "PARTITION_ROOT" "$(partition_device "${device}" "${partition_number}")"
        print_message DEBUG "Partition number: ${partition_number}, $device, ROOT: ${root_size}G"
        partition_number=$((partition_number + 1))


        print_message ACTION "Creating Home partition size: ${home_size}G"
        commands+=("sgdisk -n${partition_number}:0:0 -t${partition_number}:8300 -c${partition_number}:'HOME' ${device}") 
        set_option "PARTITION_HOME" "$(partition_device "${device}" "${partition_number}")"
        print_message DEBUG "Partition number: ${partition_number}, $device, HOME: ${home_size}G"
        partition_number=$((partition_number + 1))
    else
        root_size=$remaining_size
        print_message ACTION "Creating Root partition size: ${root_size}G"
        commands+=("sgdisk -n${partition_number}:0:0 -t${partition_number}:8300 -c${partition_number}:'ROOT' ${device}") 
        set_option "PARTITION_ROOT" "$(partition_device "${device}" "${partition_number}")"
        print_message DEBUG "Partition number: ${partition_number}, $device, ROOT: ${root_size}G"
        partition_number=$((partition_number + 1))
    fi

    print_message DEBUG "Partition string set to: boot: ${PARTITION_BOOT}, efi: ${PARTITION_EFI}, root: ${PARTITION_ROOT}, home: ${PARTITION_HOME}, swap: ${PARTITION_SWAP}"

    execute_process "Partitioning" \
        --error-message "Partitioning failed" \
        --success-message "Partitioning completed" \
        "${commands[@]}"

    # Add this debug output
    print_message DEBUG "Partitions created:"
    lsblk "${device}" || print_message WARNING "Failed to list partitions"

}
luks_setup() {
    print_message INFO "Setting up LUKS"

}
main() {
    load_config
    process_init "Partitioning the install: $DEVICE"
    print_message INFO "Starting partition process on $DEVICE"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    #prepare_drive ${INSTALL_DEVICE} ${BIOS_TYPE} || { print_message ERROR "Drive preparation failed"; return 1; }
    partitioning "${DEVICE}" ${BIOS_TYPE} || { print_message ERROR "Partitioning failed"; return 1; }

    print_message OK "Partition btrfs process completed successfully"
    process_end $?
}
# Run the main function
main "$@"
exit $?
