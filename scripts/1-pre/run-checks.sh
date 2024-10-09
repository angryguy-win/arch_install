#!/bin/sh
# Run Checks Script
# Author: ssnow
# Date: 2024
# Description: Run checks script for Arch Linux installation

set -e
trap 'exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

# shellcheck source=../../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# @description Ask for installation info
ask_passwords() {
    local passwords=""
    print_message INFO "Setting up the necessary passwords"

    # Build the passwords string
    [ "$PASSWORD" = "changeme" ] && passwords+="PASSWORD:$USERNAME "
    [ "$LUKS" = "true" ] && passwords+="LUKS_PASSWORD:LUKS "
    [ "$ROOT_SAME_AS_USER_PASSWORD" != "true" ] && [ "$ROOT_PASSWORD" = "changeme" ] && passwords+="ROOT_PASSWORD:root "
    [ -n "$WIFI_INTERFACE" ] && [ "$WIFI_KEY" = "ask" ] && passwords+="WIFI_KEY:WIFI "

    # Process each password
    for password_info in $passwords; do
        IFS=':' read -r var_name context <<< "$password_info"
        ask_password "$context" "$var_name"
    done
}
# @description Check and setup internet connection
# @noargs
check_and_setup_internet() {
    print_message INFO "Checking internet connection..."
    if ping -c 1 archlinux.org > /dev/null 2>&1; then
        print_message OK "Internet connection is available"
        return 0
    else
        print_message WARNING "No internet connection. Attempting to set up WiFi..."
        setup_wifi
        return 1
    fi
}
# @description Setup WiFi connection
# @noargs
setup_wifi() {
    local interfaces
    print_message INFO "Setting up WiFi connection..."

    # Get WiFi interface
    interfaces=$(iwctl device list | grep station | awk '{print $2}')
    if [ -z "$interfaces" ]; then
        print_message ERROR "No WiFi interfaces found."
        return 1
    fi

    # If there's only one interface, use it. Otherwise, ask the user to choose.
    if [ "$(printf '%s\n' "$interfaces" | wc -l)" -eq 1 ]; then
        WIFI_INTERFACE=$interfaces
    else
        print_message INFO "Multiple WiFi interfaces found. Please choose one:"
        i=1
        printf '%s\n' "$interfaces" | while IFS= read -r interface; do
            printf "%d) %s\n" "$i" "$interface"
            i=$((i+1))
        done
        while true; do
            printf "Enter selection: "
            read -r selection
            case $selection in
                [1-9]*)
                    WIFI_INTERFACE=$(printf '%s\n' "$interfaces" | sed -n "${selection}p")
                    [ -n "$WIFI_INTERFACE" ] && break
                    ;;
            esac
            printf "Invalid selection. Please try again.\n"
        done
    fi

    # Get SSID
    print_message INFO "Scanning for networks..."
    iwctl station "$WIFI_INTERFACE" scan
    sleep 2
    iwctl station "$WIFI_INTERFACE" get-networks

    printf "Enter the SSID of the network you want to connect to: "
    read -r WIFI_ESSID

    # Get password
    stty -echo
    printf "Enter the WiFi password: "
    read -r WIFI_KEY
    stty echo
    printf "\n"

    # Attempt to connect
    print_message INFO "Attempting to connect to %s..." "$WIFI_ESSID"
    if iwctl --passphrase "$WIFI_KEY" station "$WIFI_INTERFACE" connect "$WIFI_ESSID"; then
        print_message OK "Successfully connected to %s" "$WIFI_ESSID"
        sleep 5  # Give some time for the connection to stabilize

        # Verify internet connection
        if ping -c 1 archlinux.org > /dev/null 2>&1; then
            print_message OK "Internet connection established"
            # Save the WiFi settings to the configuration
            set_option "WIFI_INTERFACE" "$WIFI_INTERFACE"
            set_option "WIFI_ESSID" "$WIFI_ESSID"
            set_option "WIFI_KEY" "$WIFI_KEY"
            return 0
        else
            print_message ERROR "Connected to WiFi, but still no internet access"
            return 1
        fi
    else
        print_message ERROR "Failed to connect to %s" "$WIFI_ESSID"
        return 1
    fi
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
# @description Check the boot mode
# @noargs
check_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "uefi"
    else
        echo "bios"
    fi
}
# @description Prepare the drive for installation
# @arg $1 string Device to prepare
prepare_drive() {
    local device="$1"
    local partition_number=1  # Start with partition number 1
    local mount_options=""
    local bios_type=""

    print_message DEBUG "Preparing the install device $device to partition "
    if [ -z "$BIOS_TYPE" ]; then
        bios_type=$(check_boot_mode)
    else
        bios_type=${BIOS_TYPE}
    fi
    print_message DEBUG "BIOS type set to: $bios_type"
    set_option "BIOS_TYPE" "$bios_type"
    print_message INFO "Preparing drive partitions settings: "

    case "$bios_type" in
        "bios")
            set_option "PARTITION_BOOT" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))  # Increment for next partition
            ;;
        "uefi")
            set_option "PARTITION_EFI" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))  # Increment for next partition
            ;;
        "hybrid")
            set_option "PARTITION_BOOT" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))  # Increment for next partition
            set_option "PARTITION_EFI" "$(partition_device "${device}" "${partition_number}")"
            partition_number=$((partition_number + 1))  # Increment for next partition
            ;;
        *)
            print_message ERROR "Unknown BIOS type: $BIOS_TYPE"
            return 1
            ;;
    esac

    # Set the root partition
    set_option "PARTITION_ROOT" "$(partition_device "${device}" "${partition_number}")"
    partition_number=$((partition_number + 1))  # Increment for next partition

    # Check for HOME partition
    if [ "$HOME" = true ]; then
        set_option "PARTITION_HOME" "$(partition_device "${device}" "${partition_number}")"
        partition_number=$((partition_number + 1))  # Increment for next partition
    fi

    # Check for SWAP partition
    if [ "$SWAP" = true ]; then
        set_option "PARTITION_SWAP" "$(partition_device "${device}" "${partition_number}")"
        partition_number=$((partition_number + 1))  # Increment for next partition
    fi    
    # Load the config again to ensure all changes are reflected
    #load_config || { print_message ERROR "Failed to load config"; return 1; }
    print_message ACTION "Partition string set to: ${PARTITION_BOOT}, ${PARTITION_EFI}, ${PARTITION_ROOT}, ${PARTITION_HOME}, ${PARTITION_SWAP}"
}

# @description Run checks with progress indication
# @noargs
run_checks_with_progress() {
    local checks=()
    local current_check=0  # Initialize current check counter

    # Check the value of DRY_RUN
    if [ "$DRY_RUN" = "false" ]; then
        checks+=("root_check")  # Add root_check to the checks array
    else
        dry_run  # Run dry_run function
        return  # Exit the function after dry_run
    fi

    # Define the rest of the checks to run
    checks+=(
        "arch_check"
        "pacman_check"
        "docker_check"
        "show_system_info"
        "check_required_scripts"
    )

    local total_checks=${#checks[@]}  # Dynamically set total checks

    # Loop through each check
    for check in "${checks[@]}"; do
        current_check=$((current_check + 1))  # Increment the counter
        print_message INFO "[$current_check/$total_checks] Doing ${check}..."

        # Execute the check and handle errors
        if ! $check; then
            print_message ERROR "Check failed: ${check}"
            # Optionally, you can exit or continue based on your needs
            # exit 1  # Uncomment to stop on error
        fi
    done
}
timezone() {
    local time_zone
    time_zone="$(curl --fail https://ipapi.co/timezone)"
    set_option "TIMEZONE" "$time_zone"
}
# @description Prints that no root check is needed if DRY_RUN is true
dry_run() {
    print_message INFO "Dry-run: no root check needed"
}
install_log() {
    # Redirect stdout and stderr to archsetup.txt and still output to console
    exec > >(tee -i archsetup.txt)
    exec 2>&1
}
main() {
    process_init "Run Checks: pre-install preparations"
    print_message INFO "Starting the run checks process"

    install_log 
    run_checks_with_progress || { print_message ERROR "Run checks failed"; return 1; }
    #ask_for_installation_info
    ask_passwords
    check_and_setup_internet
    #ask_for_password
    show_drive_list || { print_message ERROR "Drive selection failed"; return 1; }
    prepare_drive ${INSTALL_DEVICE} || { print_message ERROR "Drive preparation failed"; return 1; }
    determine_microcode || { print_message ERROR "Microcode determination failed"; return 1; }
    timezone || { print_message ERROR "Timezone determination failed"; return 1; }
    detect_gpu_driver || { print_message ERROR "GPU driver detection failed"; return 1; }

    facts_commons
    # Re-Load the config to set all the new variables
    load_config || { print_message ERROR "Failed to load config"; return 1; }
    print_message OK "Run checks process completed successfully"
    process_end $?
}

main "$@"