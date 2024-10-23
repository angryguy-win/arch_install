#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2001,SC2155,SC2153,SC2143
# SC2034: foo appears unused. Verify it or export it.
# SC2001: See if you can use ${variable//search/replace} instead.
# SC2155 Declare and assign separately to avoid masking return values
# SC2153: Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
# SC2143: Use grep -q instead of comparing output with [ -n .. ].

# @description Common functions for the system installation.
# @author      ssnow
# @version     1.0.0
# @date        2024-02-20
# @license     GPLv3


set -eu

# set variables
BOOT_DIRECTORY=/boot
ESP_DIRECTORY=/boot
UUID_BOOT=$(blkid -s UUID -o value "$PARTITION_BOOT")
UUID_ROOT=$(blkid -s UUID -o value "$PARTITION_ROOT")
PARTUUID_BOOT=$(blkid -s PARTUUID -o value "$PARTITION_BOOT")
PARTUUID_ROOT=$(blkid -s PARTUUID -o value "$PARTITION_ROOT")

# @description Ask for installation information.
# @return 0 on success, 1 on failure
ask_for_installation_info() {
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local project_root="$( cd "$script_dir/.." && pwd )"
    local executable_path="$project_root/installation_info/installation_info"

    print_message DEBUG "Current directory: $(pwd)"
    print_message DEBUG "Script directory: $script_dir"
    print_message DEBUG "Project root: $project_root"
    print_message DEBUG "Executable path: $executable_path"

    if [ ! -f "$executable_path" ]; then
        print_message ERROR "installation_info file not found at $executable_path"
        return 1
    fi

    if [ ! -x "$executable_path" ]; then
        print_message ERROR "installation_info is not executable at $executable_path"
        chmod +x "$executable_path"
        print_message DEBUG "Made $executable_path executable"
    fi
    print_message DEBUG "Current PATH: $PATH"
    print_message DEBUG "Current working directory: $(pwd)"
    print_message DEBUG "Executable permissions: $(ls -l "$executable_path")"
    print_message DEBUG "Executable file type: $(file "$executable_path")"
    print_message DEBUG "Environment variables:"
    print_message DEBUG "USERNAME=$USERNAME"
    print_message DEBUG "USER_PASSWORD=$USER_PASSWORD"
    print_message DEBUG "HOSTNAME=$HOSTNAME"
    print_message DEBUG "TIMEZONE=$TIMEZONE"

    print_message DEBUG "Attempting to run installation_info program"
    print_message DEBUG "Command: $executable_path -interactive=false"
    
    # Explicitly set environment variables
    export USERNAME="$(sanitize "${USERNAME:-user}")"
    export USER_PASSWORD="$(sanitize "${USER_PASSWORD:-changeme}")" # Set a default password
    export HOSTNAME="$(sanitize "${HOSTNAME:-arch}")"
    export TIMEZONE="$(sanitize "${TIMEZONE:-America/Toronto}")"

    print_message DEBUG "Environment variables after setting defaults:"
    print_message DEBUG "USERNAME=$USERNAME"
    print_message DEBUG "USER_PASSWORD=$USER_PASSWORD"
    print_message DEBUG "HOSTNAME=$HOSTNAME"
    print_message DEBUG "TIMEZONE=$TIMEZONE"

    # Check if we need to run in interactive mode
    if [ -z "$USERNAME" ] || [ -z "$USER_PASSWORD" ] || [ -z "$HOSTNAME" ] || [ -z "$TIMEZONE" ]; then
        print_message DEBUG "Running installation_info in interactive mode"
        "$executable_path" -interactive=true
    else
        print_message DEBUG "Running installation_info in non-interactive mode"
        "$executable_path" -interactive=false
    fi

    exit_code=$?
    print_message DEBUG "installation_info exit code: $exit_code"

    if [ $exit_code -ne 0 ]; then
        print_message ERROR "Failed to run installation_info program. Exit code: $exit_code"
        return 1
    fi

    print_message DEBUG "Trying to execute directly from shell"
    bash -c "$executable_path -interactive=false"
    print_message DEBUG "Direct execution exit code: $?"

    print_message DEBUG "Checking library dependencies"
    ldd_output=$(ldd "$executable_path" 2>&1) || true
    if [[ $ldd_output == *"not a dynamic executable"* ]]; then
        print_message DEBUG "The executable is statically linked (this is normal for Go programs)"
    else
        print_message DEBUG "Library dependencies: $ldd_output"
    fi

    print_message DEBUG "Running strace on installation_info"
    strace "$executable_path" -interactive=false || true

    print_message SUCCESS "Installation information collected successfully!"
    return 0
}
sanitize_variable() {
    local VARIABLE="$1"
    local VARIABLE=$(echo "$VARIABLE" | sed "s/![^ ]*//g") # remove disabled
    local VARIABLE=$(echo "$VARIABLE" | sed -r "s/ {2,}/ /g") # remove unnecessary white spaces
    local VARIABLE=$(echo "$VARIABLE" | sed 's/^[[:space:]]*//') # trim leading
    local VARIABLE=$(echo "$VARIABLE" | sed 's/[[:space:]]*$//') # trim trailing
    echo "$VARIABLE"
}

trim_variable() {
    local VARIABLE="$1"
    local VARIABLE=$(echo "$VARIABLE" | sed 's/^[[:space:]]*//') # trim leading
    local VARIABLE=$(echo "$VARIABLE" | sed 's/[[:space:]]*$//') # trim trailing
    echo "$VARIABLE"
}

wipe_disk() {
    local DEVICE="$1"
    local PARTITION_MODE="$2"

    if [ "$PARTITION_MODE" == "auto" ]; then
        sgdisk --zap-all "$DEVICE"
        sgdisk -o "$DEVICE"
        wipefs -a -f "$DEVICE"
        partprobe -s "$DEVICE"
    fi
}

boot_partition() {
    local PARTITION_BOOT="$1"
    local BIOS_TYPE="$2"

    if [ "$BIOS_TYPE" == "uefi" ]; then
        mkfs.fat -n ESP -F32 "$PARTITION_BOOT"
    fi
    if [ "$BIOS_TYPE" == "bios" ]; then
        mkfs.ext4 -L boot "$PARTITION_BOOT"
    fi
}
root_partition() {
    local DEVICE_ROOT="$1"
    local FILE_SYSTEM_TYPE="$2"

    if [ "$FILE_SYSTEM_TYPE" == "ext4|btrfs" ]; then
        mkfs."$FILE_SYSTEM_TYPE" -L root "$DEVICE_ROOT"
    fi
}

home_partition() {
    local DEVICE_HOME="$1"
    local FILE_SYSTEM_TYPE="$2"

    if [ "$FILE_SYSTEM_TYPE" == "ext4|btrfs" ]; then
        mkfs."$FILE_SYSTEM_TYPE" -L home "$DEVICE_HOME"
    fi
}

swap_partition() {
    local DEVICE_SWAP="$1"
    local SWAP_SIZE="$2"

    fallocate -l "$SWAP_SIZE" "$DEVICE_SWAP"
}

partition_mount() {
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        # mount subvolumes
        mount -o "subvol=${BTRFS_SUBVOLUME_ROOT[1]},$PARTITION_OPTIONS,compress=zstd" "$DEVICE_ROOT" "${MNT_DIR}"
        mkdir -p "${MNT_DIR}"/boot
        mount -o "$PARTITION_OPTIONS_BOOT" "$PARTITION_BOOT" "${MNT_DIR}"/boot
        for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
            IFS=',' read -ra SUBVOLUME <<< "$I"
            if [ "${SUBVOLUME[0]}" == "root" ]; then
                continue
            fi
            if [ "${SUBVOLUME[0]}" == "swap" ] && [ -z "$SWAP_SIZE" ]; then
                continue
            fi
            if [ "${SUBVOLUME[0]}" == "swap" ]; then
                mkdir -p "${MNT_DIR}${SUBVOLUME[2]}"
                chmod 0755 "${MNT_DIR}${SUBVOLUME[2]}"
            else
                mkdir -p "${MNT_DIR}${SUBVOLUME[2]}"
            fi
            mount -o "subvol=${SUBVOLUME[1]},$PARTITION_OPTIONS,compress=zstd" "$DEVICE_ROOT" "${MNT_DIR}${SUBVOLUME[2]}"
        done
    else
        # root
        mount -o "$PARTITION_OPTIONS" "$DEVICE_ROOT" "${MNT_DIR}"

        # boot
        mkdir -p "${MNT_DIR}"/boot
        mount -o "$PARTITION_OPTIONS_BOOT" "$PARTITION_BOOT" "${MNT_DIR}"/boot

        # mount points
        for I in "${PARTITION_MOUNT_POINTS[@]}"; do
            if [[ "$I" =~ ^!.* ]]; then
                continue
            fi
            IFS='=' read -ra PARTITION_MOUNT_POINT <<< "$I"
            if [ "${PARTITION_MOUNT_POINT[1]}" == "/boot" ] || [ "${PARTITION_MOUNT_POINT[1]}" == "/" ]; then
                continue
            fi
            local PARTITION_DEVICE="$(partition_device "${DEVICE}" "${PARTITION_MOUNT_POINT[0]}")"
            mkdir -p "${MNT_DIR}${PARTITION_MOUNT_POINT[1]}"
            mount -o "$PARTITION_OPTIONS" "${PARTITION_DEVICE}" "${MNT_DIR}${PARTITION_MOUNT_POINT[1]}"
        done
    fi
}
create_subvolumes() {

    # create
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        # create subvolumes
        mount -o "$PARTITION_OPTIONS" "$DEVICE_ROOT" "${MNT_DIR}"
        for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
            IFS=',' read -ra SUBVOLUME <<< "$I"
            if [ "${SUBVOLUME[0]}" == "swap" ] && [ -z "$SWAP_SIZE" ]; then
                continue
            fi
            btrfs subvolume create "${MNT_DIR}/${SUBVOLUME[1]}"
        done
        umount "${MNT_DIR}"
    fi
}
swap_file() {
    # swap
    if [ -n "$SWAP_SIZE" ]; then
        if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
            SWAPFILE="${BTRFS_SUBVOLUME_SWAP[2]}$SWAPFILE"
            chattr +C "${MNT_DIR}"
            btrfs filesystem mkswapfile --size "${SWAP_SIZE}m" --uuid clear "${MNT_DIR}${SWAPFILE}"
            swapon "${MNT_DIR}${SWAPFILE}"
        else
            dd if=/dev/zero of="${MNT_DIR}$SWAPFILE" bs=1M count="$SWAP_SIZE" status=progress
            chmod 600 "${MNT_DIR}${SWAPFILE}"
            mkswap "${MNT_DIR}${SWAPFILE}"
        fi
    fi
}
install() {
    print_step "install()"
    local COUNTRIES=()
    local PACKAGES=()

    pacman -Sy --noconfirm reflector
    reflector "${COUNTRIES[@]}" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist
    sed -i 's/#Color/Color/' /etc/pacman.conf
    sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf


    PACKAGES=()
    if [ "$LVM" == "true" ]; then
        local PACKAGES+=("lvm2")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "btrfs" ]; then
        local PACKAGES+=("btrfs-progs")
    fi
    if [ "$FILE_SYSTEM_TYPE" == "ext4" ]; then
        local PACKAGES+=("e2fsprogs")
    fi

    pacstrap "${MNT_DIR}" base base-devel linux linux-firmware "${PACKAGES[@]}"
    sed -i 's/#ParallelDownloads/ParallelDownloads/' "${MNT_DIR}"/etc/pacman.conf

    if [ "$REFLECTOR" == "true" ]; then
        pacman_install "reflector"
        cat <<EOT > "${MNT_DIR}/etc/xdg/reflector/reflector.conf"
${COUNTRIES[@]}
--latest 25
--age 24
--protocol https
--completion-percent 100
--sort rate
--save /etc/pacman.d/mirrorlist
EOT
        arch-chroot "${MNT_DIR}" reflector "${COUNTRIES[@]}" --latest 25 --age 24 --protocol https --completion-percent 100 --sort rate --save /etc/pacman.d/mirrorlist
        arch-chroot "${MNT_DIR}" systemctl enable reflector.timer
    fi
    if [ "$PACKAGES_MULTILIB" == "true" ]; then
        sed -z -i 's/#\[multilib\]\n#/[multilib]\n/' "${MNT_DIR}"/etc/pacman.conf
    fi
}

configuration() {
    print_step "configuration()"

    if [ "$GPT_AUTOMOUNT" != "true" ]; then
        genfstab -U "${MNT_DIR}" >> "${MNT_DIR}/etc/fstab"

        cat <<EOT >> "${MNT_DIR}/etc/fstab"
# efivars
efivarfs /sys/firmware/efi/efivars efivarfs ro,nosuid,nodev,noexec 0 0

EOT

        if [ -n "$SWAP_SIZE" ]; then
            cat <<EOT >> "${MNT_DIR}/etc/fstab"
# swap
$SWAPFILE none swap defaults 0 0

EOT
        fi
    fi

    if [ "$DEVICE_TRIM" == "true" ]; then
        if [ "$GPT_AUTOMOUNT" != "true" ]; then
            sed -i 's/relatime/noatime/' "${MNT_DIR}"/etc/fstab
        fi
        arch-chroot "${MNT_DIR}" systemctl enable fstrim.timer
    fi

    arch-chroot "${MNT_DIR}" ln -s -f "$TIMEZONE" /etc/localtime
    arch-chroot "${MNT_DIR}" hwclock --systohc
    for LOCALE in "${LOCALES[@]}"; do
        sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen
        sed -i "s/#$LOCALE/$LOCALE/" "${MNT_DIR}"/etc/locale.gen
    done
    for VARIABLE in "${LOCALE_CONF[@]}"; do
        #localectl set-locale "$VARIABLE"
        echo -e "$VARIABLE" >> "${MNT_DIR}"/etc/locale.conf
    done
    locale-gen
    arch-chroot "${MNT_DIR}" locale-gen
    echo -e "$KEYMAP\n$FONT\n$FONT_MAP" > "${MNT_DIR}"/etc/vconsole.conf
    echo "$HOSTNAME" > "${MNT_DIR}"/etc/hostname

    if [ -n "$SWAP_SIZE" ]; then
        echo "vm.swappiness=10" > "${MNT_DIR}"/etc/sysctl.d/99-sysctl.conf
    fi

    printf "%s\n%s" "$ROOT_PASSWORD" "$ROOT_PASSWORD" | arch-chroot "${MNT_DIR}" passwd
}


provision() {
    print_step "provision()"

    (cd "$PROVISION_DIRECTORY" && cp -vr --parents . "${MNT_DIR}")
}

end() {
    local REBOOT="$1"
    printf "\n"
    printf "%s\n" "${GREEN}Arch Linux installed successfully"'!'"${NC}"
    printf "\n"

    if [ "$REBOOT" == "true" ]; then
        REBOOT="true"

        set +e
        for (( i = 15; i >= 1; i-- )); do
            read -r -s -n 1 -t 1 -p "Rebooting in $i seconds... Press Esc key to abort or press R key to reboot now."$'\n' KEY
            local CODE="$?"
            if [ "$CODE" != "0" ]; then
                continue
            fi
            if [ "$KEY" == $'\e' ]; then
                REBOOT="false"
                break
            elif [ "$KEY" == "r" ] || [ "$KEY" == "R" ]; then
                REBOOT="true"
                break
            fi
        done
    fi
    if [ "$REBOOT" == 'true' ]; then
        printf "%s\n" "${GREEN}Rebooting...${NC}"
        printf "\n"

        copy_logs
        do_reboot
    else
        copy_logs
    fi
}
copy_logs() {
    local ESCAPED_LUKS_PASSWORD=${LUKS_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_ROOT_PASSWORD=${ROOT_PASSWORD//[.[\*^$()+?{|]/[\\&]}
    local ESCAPED_USER_PASSWORD=${USER_PASSWORD//[.[\*^$()+?{|]/[\\&]}

    if [ -f "$ALIS_CONF_FILE" ]; then
        local SOURCE_FILE="$ALIS_CONF_FILE"
        local FILE="${MNT_DIR}/var/log/arch-install/$ALIS_CONF_FILE"

        mkdir -p "${MNT_DIR}"/var/log/arch-install/
        cp "$SOURCE_FILE" "$FILE"
        chown root:root "$FILE"
        chmod 600 "$FILE"
        if [ -n "$ESCAPED_LUKS_PASSWORD" ]; then
            sed -i "s/${ESCAPED_LUKS_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_ROOT_PASSWORD" ]; then
            sed -i "s/${ESCAPED_ROOT_PASSWORD}/******/g" "$FILE"
        fi
        if [ -n "$ESCAPED_USER_PASSWORD" ]; then
            sed -i "s/${ESCAPED_USER_PASSWORD}/******/g" "$FILE"
        fi
    fi

}
sanitize() {
    DEVICE=$(sanitize "$DEVICE")
    PARTITION_MODE=$(sanitize "$PARTITION_MODE")
    PARTITION_CUSTOM_PARTED_UEFI=$(sanitize "$PARTITION_CUSTOM_PARTED_UEFI")
    PARTITION_CUSTOM_PARTED_BIOS=$(sanitize "$PARTITION_CUSTOM_PARTED_BIOS")
    FILE_SYSTEM_TYPE=$(sanitize "$FILE_SYSTEM_TYPE")
    SWAP_SIZE=$(sanitize "$SWAP_SIZE")
    KERNELS=$(sanitize "$KERNELS")
    KERNELS_COMPRESSION=$(sanitize "$KERNELS_COMPRESSION")
    KERNELS_PARAMETERS=$(sanitize "$KERNELS_PARAMETERS")
    AUR_PACKAGE=$(sanitize "$AUR_PACKAGE")
    DISPLAY_DRIVER=$(sanitize "$DISPLAY_DRIVER")
    DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL=$(sanitize "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL")
    SYSTEMD_HOMED_STORAGE=$(sanitize "$SYSTEMD_HOMED_STORAGE")
    SYSTEMD_HOMED_STORAGE_LUKS_TYPE=$(sanitize "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE")
    BOOTLOADER=$(sanitize "$BOOTLOADER")
    CUSTOM_SHELL=$(sanitize "$CUSTOM_SHELL")
    DESKTOP_ENVIRONMENT=$(sanitize "$DESKTOP_ENVIRONMENT")
    DISPLAY_MANAGER=$(sanitize "$DISPLAY_MANAGER")
    SYSTEMD_UNITS=$(sanitize "$SYSTEMD_UNITS")

    for I in "${BTRFS_SUBVOLUMES_MOUNTPOINTS[@]}"; do
        IFS=',' read -ra SUBVOLUME <<< "$I"
        if [ "${SUBVOLUME[0]}" == "root" ]; then
            BTRFS_SUBVOLUME_ROOT=("${SUBVOLUME[@]}")
        elif [ "${SUBVOLUME[0]}" == "swap" ]; then
            BTRFS_SUBVOLUME_SWAP=("${SUBVOLUME[@]}")
        fi
    done

    for I in "${PARTITION_MOUNT_POINTS[@]}"; do #SC2153
        IFS='=' read -ra PARTITION_MOUNT_POINT <<< "$I"
        if [ "${PARTITION_MOUNT_POINT[1]}" == "/boot" ]; then
            PARTITION_BOOT_NUMBER="${PARTITION_MOUNT_POINT[0]}"
        elif [ "${PARTITION_MOUNT_POINT[1]}" == "/" ]; then
            PARTITION_ROOT_NUMBER="${PARTITION_MOUNT_POINT[0]}"
        fi
    done
}
cleanup() {
    local exit_code=$?
    print_message INFO "Performing cleanup..."

    # Restore original configuration files if backups exist
    [ -f "/mnt/etc/mkinitcpio.conf.bak" ] && mv "/mnt/etc/mkinitcpio.conf.bak" "/mnt/etc/mkinitcpio.conf"
    [ -f "/mnt/etc/default/grub.bak" ] && mv "/mnt/etc/default/grub.bak" "/mnt/etc/default/grub"

    # Remove any partial boot entries
    if [ "$BOOTLOADER" == "systemd" ]; then
        rm -f "/mnt$ESP_DIRECTORY/loader/entries/arch-*.conf"
    fi

    # Log the exit status
    if [ $exit_code -ne 0 ]; then
        print_message ERROR "Script exited with error code $exit_code"
        # You could add more detailed logging or error reporting here
    fi

    print_message INFO "Cleanup completed"
    exit $exit_code
}


