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
select_default_kernel {
  local kernellist
  local kernels
  local option

  if [ "$(stat -c "%u" /boot)" -eq 0 ]; then
    show_info "'/boot' owned by root. Searching as root:"
    mapfile -t kernellist < \
      <(sudo find /boot -maxdepth 1 -name 'vmlinuz-*' -type f -print0 |
        xargs -0 -I _ basename _ |
        sed -e "s/^vmlinuz-//g")
  else
    mapfile -t kernellist < \
      <(find /boot -maxdepth 1 -name 'vmlinuz-*' -type f -print0 |
        xargs -0 -I _ basename _ |
        sed -e "s/^vmlinuz-//g")
  fi

  kernels=("Back" "${kernellist[@]}")

  show_question "Select a default kernel:"
  select option in "${kernels[@]}"; do
    case "${option}" in
      Back)
        break
        ;;
      linux | linux-lts | linux-zen | linux-hardened | linux-rt | linux-rt-lts)
        KERNEL="${option}"
        set_default_kernel
        break
        ;;
      *)
        show_error "Invalid option ${option@Q}."
        break
        ;;
    esac
  done
}

set_default_kernel {
  local grubdefault="/etc/default/grub"
  local grubcfg="/boot/grub/grub.cfg"
  local mksdbootcfg="${DIR}/utils/sdboot-mkconfig"

  show_info "Setting default boot kernel to ${KERNEL}."

  if [ -f "${grubdefault}" ]; then
    sudo sed -i "s/^GRUB_DEFAULT=.*$/GRUB_DEFAULT='Advanced options for Arch Linux>Arch Linux, with Linux ${KERNEL}'/g" ${grubdefault}
    sudo grub-mkconfig -o ${grubcfg}
  fi

  if [[ "$(sudo bootctl is-installed)" = yes ]]; then
    local sdbootcfg
    sdbootcfg="$(bootctl -p)/loader/loader.conf"
    if ! [ -f "$(bootctl -p)/loader/entries/${KERNEL}.conf" ]; then
      sudo "${mksdbootcfg}" "${KERNEL}"
    fi
    sudo sed -i "s/^default\(\s\+\)\(.*\)/default\1${KERNEL}.conf/g" "${sdbootcfg}"
  fi
}
select_plymouth_theme {
  if command -v plymouth-set-default-theme > /dev/null; then
    show_info "Select Plymouth theme:"
    local choice
    local choices
    mapfile -t choices < <(plymouth-set-default-theme -l)
    select choice in Back default "${choices[@]}"; do
      set_plymouth_theme "${choice}"
      break
    done
  else
    show_warning "'plymouth-set-default-theme' executable not found. Skipping."
  fi
}
set_plymouth_theme {
  local theme="${1:-default}"
  if command -v plymouth-set-default-theme > /dev/null; then
    case "${theme}" in
      Back)
        return
        ;;
      default)
        sudo plymouth-set-default-theme -r -R
        ;;
      breeze-text)
        show_warning "WARNING: ${theme@Q} not working as of 03/07/2024."
        ;;
      *)
        sudo plymouth-set-default-theme -R "${theme}"
        ;;
    esac
  else
    show_warning "'plymouth-set-default-theme' executable not found. Skipping."
  fi
}
select_icon_theme {
  show_question "Select an icon theme:"

  local options=(
    "Back"
    "Adwaita"
    "Breeze"
    "Breeze-Dark"
    "Papirus"
    "ePapirus"
    "ePapirus-Dark"
    "Papirus-Light"
    "Papirus-Dark"
    "Papirus-Adapta"
    "Papirus-Adapta-Nokto")
  local option
  select option in "${options[@]}"; do
    case "${option}" in
      "Back")
        return
        ;;
      "Adwaita")
        if [ -d /usr/share/icons/Adwaita ]; then
          ICONTHEME="Adwaita"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Breeze")
        if [ -d /usr/share/icons/breeze ]; then
          ICONTHEME="breeze"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Breeze-Dark")
        if [ -d /usr/share/icons/breeze-dark ]; then
          ICONTHEME="breeze-dark"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Papirus")
        if [ -d /usr/share/icons/Papirus ] ||
           [ -d /usr/local/share/icons/Papirus ] ||
           [ -d "${HOME}/.local/share/icons/Papirus" ] ||
           [ -d "${HOME}/.icons/Papirus" ]; then
          ICONTHEME="Papirus"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "ePapirus")
        if [ -d /usr/share/icons/ePapirus ] ||
           [ -d /usr/local/share/icons/ePapirus ] ||
           [ -d "${HOME}/.local/share/icons/ePapirus" ] ||
           [ -d "${HOME}/.icons/ePapirus" ]; then
          ICONTHEME="ePapirus"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "ePapirus-Dark")
        if [ -d /usr/share/icons/ePapirus-Dark ] ||
           [ -d /usr/local/share/icons/ePapirus-Dark ] ||
           [ -d "${HOME}/.local/share/icons/ePapirus-Dark" ] ||
           [ -d "${HOME}/.icons/ePapirus-Dark" ]; then
          ICONTHEME="ePapirus-Dark"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Papirus-Light")
        if [ -d /usr/share/icons/Papirus-Light ] ||
           [ -d /usr/local/share/icons/Papirus-Light ] ||
           [ -d "${HOME}/.local/share/icons/Papirus-Light" ] ||
           [ -d "${HOME}/.icons/Papirus-Light" ]; then
          ICONTHEME="Papirus-Light"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Papirus-Dark")
        if [ -d /usr/share/icons/Papirus-Dark ] ||
           [ -d /usr/local/share/icons/Papirus-Dark ] ||
           [ -d "${HOME}/.local/share/icons/Papirus-Dark" ] ||
           [ -d "${HOME}/.icons/Papirus-Dark" ]; then
          ICONTHEME="Papirus-Dark"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Papirus-Adapta")
        if [ -d /usr/share/icons/Papirus-Adapta ] ||
           [ -d /usr/local/share/icons/Papirus-Adapta ] ||
           [ -d "${HOME}/.local/share/icons/Papirus-Adapta" ] ||
           [ -d "${HOME}/.icons/Papirus-Adapta" ]; then
          ICONTHEME="Papirus-Adapta"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      "Papirus-Adapta-Nokto")
        if [ -d /usr/share/icons/Papirus-Adapta-Nokto ] ||
           [ -d /usr/local/share/icons/Papirus-Adapta-Nokto ] ||
           [ -d "${HOME}/.local/share/icons/Papirus-Adapta-Nokto" ] ||
           [ -d "${HOME}/.icons/Papirus-Adapta-Nokto" ]; then
          ICONTHEME="Papirus-Adapta-Nokto"
          break
        else
          show_warning "${option@Q} icons are not installed."
        fi
        ;;
      *)
        show_warning "Invalid option ${option@Q}."
        ;;
    esac
  done

  set_icon_theme
  set_lightdm_theme
}
select_plasma_theme {
  show_question "Select a Plasma theme:"

  local options=(
    "Back"
    "Arc"
    "Arc-Dark"
    "Arc-Darker"
    "Breeze"
    "Breeze-dark"
    "Breeze-twilight"
    "Materia"
    "Materia-dark"
    "Materia-light")
  local option
  select option in "${options[@]}"; do
    case "${option}" in
      "Back")
        return
        ;;
      "Arc")
        if [ -d /usr/share/plasma/look-and-feel/com.github.sudorook.arc/ ] ||
           [ -d /usr/local/share/plasma/look-and-feel/com.github.sudorook.arc/ ]; then
          PLASMATHEME="Arc"
          GTKTHEME="Arc"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc-Darker")
        if [ -d /usr/share/plasma/look-and-feel/com.github.sudorook.arc-darker ] ||
           [ -d /usr/local/share/plasma/look-and-feel/com.github.sudorook.arc-darker ]; then
          PLASMATHEME="Arc-Darker"
          GTKTHEME="Arc-Dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc-Dark")
        if [ -d /usr/share/plasma/look-and-feel/com.github.sudorook.arc-dark ] ||
           [ -d /usr/local/share/plasma/look-and-feel/com.github.sudorook.arc-dark ]; then
          PLASMATHEME="Arc-Dark"
          GTKTHEME="Arc-Dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Breeze")
        if [ -d /usr/share/plasma/look-and-feel/org.kde.breeze.desktop ] ||
           [ -d /usr/local/share/plasma/look-and-feel/org.kde.breeze.desktop ]; then
          PLASMATHEME="breeze"
          GTKTHEME="Breeze"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Breeze-dark")
        if [ -d /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop ] ||
           [ -d /usr/local/share/plasma/look-and-feel/org.kde.breezedark.desktop ]; then
          PLASMATHEME="breeze-dark"
          GTKTHEME="Breeze"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Breeze-twilight")
        if [ -d /usr/share/plasma/look-and-feel/org.kde.breezetwilight.desktop ] ||
           [ -d /usr/local/share/plasma/look-and-feel/org.kde.breezetwilight.desktop ]; then
          PLASMATHEME="breeze-twilight"
          GTKTHEME="Breeze"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia")
        if [ -d /usr/share/plasma/desktoptheme/Materia ] ||
           [ -d /usr/local/share/plasma/desktoptheme/Materia ]; then
          PLASMATHEME="Materia"
          GTKTHEME="Materia"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-light")
        if [ -d /usr/share/plasma/desktoptheme/Materia-light ] ||
           [ -d /usr/local/share/plasma/desktoptheme/Materia-light ]; then
          PLASMATHEME="Materia-light"
          GTKTHEME="Materia-light"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-dark")
        if [ -d /usr/share/plasma/desktoptheme/Materia-dark ] ||
           [ -d /usr/local/share/plasma/desktoptheme/Materia-dark ]; then
          PLASMATHEME="Materia-dark"
          GTKTHEME="Materia-dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      *)
        show_warning "Invalid option ${option@Q}."
        ;;
    esac
  done

  set_plasma_theme
  set_gtk_theme
  set_sddm_theme
}
select_gtk_theme {
  show_question "Select a GTK theme:"

  local options=(
    "Back"
    "Adwaita"
    "Adwaita-dark"
    "Arc"
    "Arc-Darker"
    "Arc-Dark"
    "Arc-Lighter"
    "Adapta"
    "Adapta-Eta"
    "Adapta-Nokto"
    "Adapta-Nokto-Eta"
    "Materia"
    "Materia-compact"
    "Materia-dark"
    "Materia-dark-compact"
    "Materia-light"
    "Materia-light-compact"
    "Plata"
    "Plata-Compact"
    "Plata-Lumine"
    "Plata-Lumine-Compact"
    "Plata-Noir"
    "Plata-Noir-Compact")
  local option
  select option in "${options[@]}"; do
    case "${option}" in
      "Back")
        return
        ;;
      "Adwaita")
        if [ -d /usr/share/themes/Adwaita ]; then
          GTKTHEME="Adwaita"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Adwaita-dark")
        if [ -d /usr/share/themes/Adwaita-dark ]; then
          GTKTHEME="Adwaita-dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc")
        if [ -d /usr/share/themes/Arc ] ||
           [ -d /usr/local/share/themes/Arc ] ||
           [ -d "${HOME}/.local/share/themes/Arc" ] ||
           [ -d "${HOME}/.themes/Arc" ]; then
          GTKTHEME="Arc"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc-Darker")
        if [ -d /usr/share/themes/Arc-Darker ] ||
           [ -d /usr/local/share/themes/Arc-Darker ] ||
           [ -d "${HOME}/.local/share/themes/Arc-Darker" ] ||
           [ -d "${HOME}/.themes/Arc-Darker" ]; then
          GTKTHEME="Arc-Darker"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc-Dark")
        if [ -d /usr/share/themes/Arc-Dark ] ||
           [ -d /usr/local/share/themes/Arc-Dark ] ||
           [ -d "${HOME}/.local/share/themes/Arc-Dark" ] ||
           [ -d "${HOME}/.themes/Arc-Dark" ]; then
          GTKTHEME="Arc-Dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Arc-Lighter")
        if [ -d /usr/share/themes/Arc-Lighter ] ||
           [ -d /usr/local/share/themes/Arc-Lighter ] ||
           [ -d "${HOME}/.local/share/themes/Arc-Lighter" ] ||
           [ -d "${HOME}/.themes/Arc-Lighter" ]; then
          GTKTHEME="Arc-Lighter"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Adapta")
        if [ -d /usr/share/themes/Adapta ] ||
           [ -d /usr/local/share/themes/Adapta ] ||
           [ -d "${HOME}/.local/share/themes/Adapta" ] ||
           [ -d "${HOME}/.themes/Adapta" ]; then
          GTKTHEME="Adapta"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Adapta-Eta")
        if [ -d /usr/share/themes/Adapta-Eta ] ||
           [ -d /usr/local/share/themes/Adapta-Eta ] ||
           [ -d "${HOME}/.local/share/themes/Adapta-Eta" ] ||
           [ -d "${HOME}/.themes/Adapta-Eta" ]; then
          GTKTHEME="Adapta-Eta"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Adapta-Nokto")
        if [ -d /usr/share/themes/Adapta-Nokto ] ||
           [ -d /usr/local/share/themes/Adapta-Nokto ] ||
           [ -d "${HOME}/.local/share/themes/Adapta-Nokto" ] ||
           [ -d "${HOME}/.themes/Adapta-Nokto" ]; then
          GTKTHEME="Adapta-Nokto"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Adapta-Nokto-Eta")
        if [ -d /usr/share/themes/Adapta-Nokto-Eta ] ||
           [ -d /usr/local/share/themes/Adapta-Nokto-Eta ] ||
           [ -d "${HOME}/.local/share/themes/Adapta-Nokto-Eta" ] ||
           [ -d "${HOME}/.themes/Adapta-Nokto-Eta" ]; then
          GTKTHEME="Adapta-Nokto-Eta"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia")
        if [ -d /usr/share/themes/Materia ] ||
           [ -d /usr/local/share/themes/Materia ] ||
           [ -d "${HOME}/.local/share/themes/Materia" ] ||
           [ -d "${HOME}/.themes/Materia" ]; then
          GTKTHEME="Materia"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-compact")
        if [ -d /usr/share/themes/Materia-compact ] ||
           [ -d /usr/local/share/themes/Materia-compact ] ||
           [ -d "${HOME}/.local/share/themes/Materia-compact" ] ||
           [ -d "${HOME}/.themes/Materia-compact" ]; then
          GTKTHEME="Materia-compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-light")
        if [ -d /usr/share/themes/Materia-light ] ||
           [ -d /usr/local/share/themes/Materia-light ] ||
           [ -d "${HOME}/.local/share/themes/Materia-light" ] ||
           [ -d "${HOME}/.themes/Materia-light" ]; then
          GTKTHEME="Materia-light"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-light-compact")
        if [ -d /usr/share/themes/Materia-light-compact ] ||
           [ -d /usr/local/share/themes/Materia-light-compact ] ||
           [ -d "${HOME}/.local/share/themes/Materia-light-compact" ] ||
           [ -d "${HOME}/.themes/Materia-light-compact" ]; then
          GTKTHEME="Materia-light-compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-dark")
        if [ -d /usr/share/themes/Materia-dark ] ||
           [ -d /usr/local/share/themes/Materia-dark ] ||
           [ -d "${HOME}/.local/share/themes/Materia-dark" ] ||
           [ -d "${HOME}/.themes/Materia-dark" ]; then
          GTKTHEME="Materia-dark"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Materia-dark-compact")
        if [ -d /usr/share/themes/Materia-dark-compact ] ||
           [ -d /usr/local/share/themes/Materia-dark-compact ] ||
           [ -d "${HOME}/.local/share/themes/Materia-dark-compact" ] ||
           [ -d "${HOME}/.themes/Materia-dark-compact" ]; then
          GTKTHEME="Materia-dark-compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata")
        if [ -d /usr/share/themes/Plata ] ||
           [ -d /usr/local/share/themes/Plata ] ||
           [ -d "${HOME}/.local/share/themes/Plata" ] ||
           [ -d "${HOME}/.themes/Plata" ]; then
          GTKTHEME="Plata"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata-Compact")
        if [ -d /usr/share/themes/Plata-Compact ] ||
           [ -d /usr/local/share/themes/Plata-Compact ] ||
           [ -d "${HOME}/.local/share/themes/Plata-Compact" ] ||
           [ -d "${HOME}/.themes/Plata-Compact" ]; then
          GTKTHEME="Plata-Compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata-Lumine")
        if [ -d /usr/share/themes/Plata-Lumine ] ||
           [ -d /usr/local/share/themes/Plata-Lumine ] ||
           [ -d "${HOME}/.local/share/themes/Plata-Lumine" ] ||
           [ -d "${HOME}/.themes/Plata-Lumine" ]; then
          GTKTHEME="Plata-Lumine"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata-Lumine-Compact")
        if [ -d /usr/share/themes/Plata-Lumine-Compact ] ||
           [ -d /usr/local/share/themes/Plata-Lumine-Compact ] ||
           [ -d "${HOME}/.local/share/themes/Plata-Lumine-Compact" ] ||
           [ -d "${HOME}/.themes/Plata-Lumine-Compact" ]; then
          GTKTHEME="Plata-Lumine-Compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata-Noir")
        if [ -d /usr/share/themes/Plata-Noir ] ||
           [ -d /usr/local/share/themes/Plata-Noir ] ||
           [ -d "${HOME}/.local/share/themes/Plata-Noir" ] ||
           [ -d "${HOME}/.themes/Plata-Noir" ]; then
          GTKTHEME="Plata-Noir"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      "Plata-Noir-Compact")
        if [ -d /usr/share/themes/Plata-Noir-Compact ] ||
           [ -d /usr/local/share/themes/Plata-Noir-Compact ] ||
           [ -d "${HOME}/.local/share/themes/Plata-Noir-Compact" ] ||
           [ -d "${HOME}/.themes/Plata-Noir-Compact" ]; then
          GTKTHEME="Plata-Noir-Compact"
          break
        else
          show_warning "${option@Q} theme is not installed."
        fi
        ;;
      *)
        show_warning "Invalid option ${option@Q}."
        ;;
    esac
  done

  set_gtk_theme
  set_lightdm_theme
  set_gdm_theme
}
enable_autologin {
  local gdmconf="/etc/gdm/custom.conf"
  local lightdmconf="/etc/lightdm/lightdm.conf"
  local sddmconf="/etc/sddm.conf.d/kde_settings.conf"

  show_header "Enabling automatic login for ${USER@Q}."
  local is_autologin_set=false

  if pacman -Qi gdm > /dev/null 2>&1; then
    show_info "Log in as ${USER@Q} via GDM."
    ! [ -f ${gdmconf} ] && sudo touch ${gdmconf}
    if ! grep -q "^AutomaticLogin=${USER}" ${gdmconf}; then
      ! grep -q '^\[daemon\]' "${gdmconf}" &&
        sudo sh -c "echo '[daemon]' >> ${gdmconf}"
      sudo sed -i "/^\[daemon\]$/a AutomaticLogin=${USER}" "${gdmconf}"
      sudo sed -i "/^AutomaticLogin=/a AutomaticLoginEnable=true" "${gdmconf}"
    else
      sudo sed -i "s/^AutomaticLogin=.*$/AutomaticLogin=${USER}/g" ${gdmconf}
      sudo sed -i "s/^AutomaticLoginEnable=.*$/AutomaticLoginEnable=true/g" ${gdmconf}
    fi
    is_autologin_set=true
  fi

  if pacman -Qi lightdm > /dev/null 2>&1; then
    show_info "Log in as ${USER@Q} via LightDM."
    if ! grep -q autologin <(getent group); then
      sudo groupadd -r autologin
    fi
    if ! [[ $(groups) =~ autologin ]]; then
      sudo gpasswd -a "${USER}" autologin
    fi
    sudo sed -i "s/^#autologin-user=/autologin-user=/g" ${lightdmconf}
    sudo sed -i "s/^#autologin-user-timeout=/autologin-user-timeout=/g" ${lightdmconf}
    sudo sed -i "s/^autologin-user=.*$/autologin-user=${USER}/g" ${lightdmconf}
    is_autologin_set=true
  fi

  if pacman -Qi sddm > /dev/null 2>&1; then
    show_info "Log in as ${USER@Q} via SDDM."
    local kwconfig
    local plasmaversion
    plasmaversion="$(plasmashell --version)"
    if kwconfig="$(_get_kwrite_config)"; then
      if ! [ -d /etc/sddm.conf.d/ ]; then
        sudo mkdir /etc/sddm.conf.d/
        sudo touch "${sddmconf}"

        sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Relogin "false"
        if [[ "${plasmaversion}" =~ 6\.[0-9]+\.[0-9]+$ ]]; then
          sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Session "${DESKTOP_SESSION:-plasma}"
        elif [[ "${plasmaversion}" =~ 5\.[0-9]+\.[0-9]+$ ]]; then
          sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Session "${DESKTOP_SESSION:-plasmawayland}"
        fi
        sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key User "${USER}"

        sudo "${kwconfig}" --file "${sddmconf}" --group General --key HaltCommand ""
        sudo "${kwconfig}" --file "${sddmconf}" --group General --key RebootCommand ""

        sudo "${kwconfig}" --file "${sddmconf}" --group Theme --key Current ""

        sudo "${kwconfig}" --file "${sddmconf}" --group Users --key MaximumUid 60000
        sudo "${kwconfig}" --file "${sddmconf}" --group Users --key MinimumUid 1000
      else
        sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Relogin "false"
        if [[ "${plasmaversion}" =~ 6\.[0-9]+\.[0-9]+$ ]]; then
          sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Session "${DESKTOP_SESSION:-plasma}"
        elif [[ "${plasmaversion}" =~ 5\.[0-9]+\.[0-9]+$ ]]; then
          sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key Session "${DESKTOP_SESSION:-plasmawayland}"
        fi
        sudo "${kwconfig}" --file "${sddmconf}" --group Autologin --key User "${USER}"
      fi
      is_autologin_set=true
    fi
  fi

  if "${is_autologin_set}"; then
    show_success "Autologin enabled."
  else
    show_warning "Failed to detect display manager. Autologin not enabled."
  fi
}
 hide_avahi_apps {
  local systemappsdir="/usr/share/applications"
  local localappsdir="${HOME}/.local/share/applications"
  show_header "Hiding Avahi applications."
  local avahiapps=("avahi-discover" "bssh" "bvnc")
  local app
  mkdir -p "${localappsdir}"
  for app in "${avahiapps[@]}"; do
    cp "${systemappsdir}/${app}.desktop" "${localappsdir}/"
    echo "Hidden=true" >> "${localappsdir}/${app}.desktop"
  done
}
set_dark_gtk {
  local gtksettings="${HOME}/.config/gtk-3.0/settings.ini"
  local isgtkdark

  show_header "Setting global dark theme for gtk applications."
  mkdir -p "$(dirname "${gtksettings}")"
  if [ -f "${gtksettings}" ]; then
    if grep -q ^gtk-application-prefer-dark-theme= "${gtksettings}"; then
      isgtkdark=$(sed -n 's/^gtk-application-prefer-dark-theme\s*=\s*\(.*\)\s*/\1/p' "${gtksettings}")
      if test "${isgtkdark}"; then
        show_info "Desktop is already set to use dark GTK variants."
      else
        sed -i "s/^gtk-application-prefer-dark-theme=${isgtkdark}$/gtk-application-prefer-dark-theme=1/g" "${gtksettings}"
      fi
    else
      if grep -q "^\[Settings\]" "${gtksettings}"; then
        sed -i "/^\[Settings\]/a gtk-application-prefer-dark-theme=1" "${gtksettings}"
      else
        cat >> "${gtksettings}" << EOF

[Settings]
gtk-application-prefer-dark-theme=1
EOF
      fi
    fi
  else
    cat > "${gtksettings}" << EOF
[Settings]
gtk-application-prefer-dark-theme=1
EOF
  fi
}
set_login_shell {
  local options=(
    "Back"
    "bash"
    "zsh"
  )
  local option
  select option in "${options[@]}"; do
    case "${option}" in
      "Back")
        return
        ;;
      "bash")
        set_bash_shell
        break
        ;;
      "zsh")
        set_zsh_shell
        break
        ;;
    esac
  done
}
set_zsh_shell {
  local zshrc="${DIR}/dotfiles/zshrc"
  local p10krc="${DIR}/dotfiles/p10k"

  if ! command -v zsh > /dev/null 2>&1; then
    show_warning "Zsh not installed. Skipping."
    return
  fi

  if ! grep -q "zsh" <(getent passwd "$(whoami)"); then
    show_info "Changing login shell to Zsh. Provide your password."
    chsh -s /bin/zsh
  else
    show_info "Default shell already set to Zsh."
  fi

  mkdir -p "${HOME}/.local/share/zsh/site-functions"

  copy_config_file "${zshrc}" "${HOME}/.zshrc"
  copy_config_file "${p10krc}" "${HOME}/.p10k.zsh"
}
set_bash_shell {
  local bashrc="${DIR}/dotfiles/bashrc"
  local bashprofile="${DIR}/dotfiles/bash_profile"

  if ! command -v bash > /dev/null 2>&1; then
    show_warning "bash not installed. Skipping."
    return
  fi

  if ! grep -q "bash" <(getent passwd "$(whoami)"); then
    show_info "Changing login shell to Bash. Provide your password."
    chsh -s /bin/bash
  else
    show_info "Default shell already set to bash."
  fi

  copy_config_file "${bashprofile}" "${HOME}/.bash_profile"
  copy_config_file "${bashrc}" "${HOME}/.bashrc"
}
set_sddm_theme {
  local sddmconf="/etc/sddm.conf.d/kde_settings.conf"
  local sddmtheme
  if [[ "${PLASMATHEME}" =~ ^breeze ]]; then
    sddmtheme=breeze
  else
    sddmtheme=${PLASMATHEME}
  fi
  if pacman -Qi sddm > /dev/null 2>&1; then
    if [ -d "/usr/share/sddm/themes/${sddmtheme}" ]; then
      show_header "Setting SDDM login theme to ${sddmtheme@Q}."
      local kwconfig
      if kwconfig="$(_get_kwrite_config)"; then
        sudo "${kwconfig}" --file "${sddmconf}" --group Theme --key Current "${sddmtheme}"
        if [[ "${sddmtheme}" = breeze ]]; then
          sudo "${kwconfig}" --file "${sddmconf}" --group Theme --key CursorTheme "breeze_cursors"
        fi
        case "${FONT}" in
          Noto)
            if pacman -Qi noto-fonts > /dev/null 2>&1; then
              sudo "${kwconfig}" --file "${sddmconf}" --group Theme --key Font "Noto Sans,10,-1,5,50,0,0,0,0,0"
            fi
            ;;
          Roboto)
            if pacman -Qi ttf-roboto > /dev/null 2>&1; then
              sudo "${kwconfig}" --file "${sddmconf}" --group Theme --key Font "Roboto,10,-1,5,50,0,0,0,0,0"
            fi
            ;;
          *) ;;
        esac
      fi
    else
      show_warning "SDDM theme for ${PLASMATHEME@Q} not found. Skipping."
    fi
  else
    show_warning "SDDM not installed. Skipping."
  fi
}
 set_gdm_theme {
  local gtkthemedir
  if pacman -Qi gdm > /dev/null 2>&1; then
    if [[ -d "/usr/local/share/themes/${GTKTHEME}" ]]; then
      gtkthemedir="/usr/local/share/themes/${GTKTHEME}"
    elif [[ -d "${HOME}/.local/share/themes/${GTKTHEME}" ]]; then
      gtkthemedir="${HOME}/.local/share/themes/${GTKTHEME}"
    elif [[ -d "${HOME}/.themes/${GTKTHEME}" ]]; then
      gtkthemedir="${HOME}/.themes/${GTKTHEME}"
    elif [[ -d "/usr/share/themes/${GTKTHEME}" ]]; then
      gtkthemedir="/usr/share/themes/${GTKTHEME}"
    else
      show_warning "GTK theme ${GTKTHEME@Q} not found. Skipping."
      return
    fi
    show_header "Setting GDM login theme to ${GTKTHEME@Q}."
    sudo cp -r "/usr/share/gnome-shell" "/usr/share/gnome-shell-$(date +%Y%m%d-%H%M%S)"
    if [[ "${GTKTHEME}" =~ ^Adapta ]] || [[ "${GTKTHEME}" =~ ^Plata ]]; then
      sudo cp -rf \
        "${gtkthemedir}"/gnome-shell/* \
        /usr/share/gnome-shell/
      sudo cp -f \
        "${gtkthemedir}"/gnome-shell/extensions/window-list/classic.css \
        /usr/share/gnome-shell/extensions/window-list@gnome-shell-extensions.gcampax.github.com/
      sudo cp -f \
        "${gtkthemedir}"/gnome-shell/extensions/window-list/stylesheet.css \
        /usr/share/gnome-shell/extensions/window-list@gnome-shell-extensions.gcampax.github.com/
    elif [[ "${GTKTHEME}" =~ ^Materia ]]; then
      sudo glib-compile-resources \
        --target="/usr/share/gnome-shell/gnome-shell-theme.gresource" \
        --sourcedir="${gtkthemedir}/gnome-shell" \
        "${gtkthemedir}/gnome-shell/gnome-shell-theme.gresource.xml"
    elif [[ "${GTKTHEME}" =~ ^Arc ]]; then
      if [[ "${GTKTHEME}" =~ Dark ]]; then
        if [ -f "${gtkthemedir}/gnome-shell/gnome-shell-theme-dark.gresource" ]; then
          sudo cp -f "${gtkthemedir}/gnome-shell/gnome-shell-theme-dark.gresource" \
            "/usr/share/gnome-shell/gnome-shell-theme.gresource"
        fi
      else
        if [ -f "${gtkthemedir}/gnome-shell/gnome-shell-theme.gresource" ]; then
          sudo cp -f "${gtkthemedir}/gnome-shell/gnome-shell-theme.gresource" \
            "/usr/share/gnome-shell/gnome-shell-theme.gresource"
        fi
      fi
    elif [[ "${GTKTHEME}" =~ ^Adwaita ]]; then
      show_info "Reinstalling GNOME-shell to reset theme files."
      sudo pacman -S --noconfirm gnome-shell gnome-shell-extensions
    else
      show_warning "${GTKTHEME@Q} theme for GDM is unsupported."
    fi
  else
    show_warning "GDM is not installed. Skipping."
  fi
}
set_lightdm_theme {
  local lightdmgtkconf="/etc/lightdm/lightdm-gtk-greeter.conf"
  if pacman -Qi lightdm-gtk-greeter > /dev/null 2>&1; then
    show_header "Setting LightDM login GTK theme to ${GTKTHEME@Q}."
    sudo sed -i "s/^#theme-name=$/theme-name=/g" ${lightdmgtkconf}
    sudo sed -i "s/^theme-name=.*/theme-name=${GTKTHEME}/g" ${lightdmgtkconf}
    sudo sed -i "s/^#icon-theme-name=$/icon-theme-name=/g" ${lightdmgtkconf}
    sudo sed -i "s/^icon-theme-name=.*$/icon-theme-name=${ICONTHEME}/g" ${lightdmgtkconf}
    if [[ "${FONT}" == "Noto" ]]; then
      if pacman -Qi noto-fonts > /dev/null 2>&1; then
        sudo sed -i "s/^#font-name=$/font-name=/g" ${lightdmgtkconf}
        sudo sed -i "s/^font-name=.*/font-name=Noto Sans/g" ${lightdmgtkconf}
      fi
    elif [[ "${FONT}" == "Roboto" ]]; then
      if pacman -Qi ttf-roboto > /dev/null 2>&1; then
        sudo sed -i "s/^#font-name=$/font-name=/g" ${lightdmgtkconf}
        sudo sed -i "s/^font-name=.*/font-name=Roboto/g" ${lightdmgtkconf}
      fi
    fi
    sudo sed -i "s/^#xft-hintstyle=$/xft-hintstyle=/g" ${lightdmgtkconf}
    sudo sed -i "s/^xft-hintstyle=.*$/xft-hintstyle=slight/g" ${lightdmgtkconf}
  else
    show_warning "LightDM GTK greeter not installed. Skipping."
  fi
}
set_plasma_theme {
  show_header "Setting Plasma theme to ${PLASMATHEME@Q}."
  local kwconfig
  local qdb
  if kwconfig="$(_get_kwrite_config)" && qdb="$(_get_qdbus)"; then
    case "${PLASMATHEME,,}" in
      arc)
        plasma-apply-lookandfeel -a com.github.sudorook.arc
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Arc"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set Arc
        ;;
      arcdark | arc-dark)
        plasma-apply-lookandfeel -a com.github.sudorook.arc-dark
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Arc-Dark"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set ArcDark
        ;;
      arc-darker | arcdarker)
        plasma-apply-lookandfeel -a com.github.sudorook.arc-darker
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Arc-Darker"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set ArcDarker
        ;;
      breeze)
        plasma-apply-lookandfeel -a org.kde.breeze.desktop
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Breeze"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "Breeze"
        ;;
      breeze-dark | breezedark)
        plasma-apply-lookandfeel -a org.kde.breezedark.desktop
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Breeze"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "Breeze"
        ;;
      breeze-twilight | breezetwilight)
        plasma-apply-lookandfeel -a org.kde.breezetwilight.desktop
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Breeze"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "Breeze"
        ;;
      materia)
        plasma-apply-lookandfeel -a com.github.sudorook.materia
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Materia"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set Materia
        ;;
      materiadark | materia-dark)
        plasma-apply-lookandfeel -a com.github.sudorook.materia-dark
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Materia-dark"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set MateriaDark
        ;;
      materialight | materia-light)
        plasma-apply-lookandfeel -a com.github.sudorook.materia-light
        "${qdb}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme "Materia-light"
        "${kwconfig}" --file kdeglobals --group "KDE" --key "widgetStyle" "kvantum"
        kvantummanager --set MateriaLight
        ;;
    esac
  fi
}
set_gtk_theme {
  if pacman -Qi cinnamon > /dev/null 2>&1; then
    show_info "Setting Cinnamon GTK theme to ${GTKTHEME@Q}."
    gsettings set org.cinnamon.desktop.interface gtk-theme "'${GTKTHEME}'"
    if [[ "${GTKTHEME}" =~ -Eta$ ]]; then
      gsettings set org.cinnamon.theme name "'${GTKTHEME%-*}'"
      gsettings set org.cinnamon.desktop.wm.preferences theme "'${GTKTHEME}'"
    elif [[ "${GTKTHEME}" =~ -Compact$ ]]; then
      gsettings set org.cinnamon.theme name "'${GTKTHEME%-*}'"
      gsettings set org.cinnamon.desktop.wm.preferences theme "'${GTKTHEME}'"
    elif [[ "${GTKTHEME}" =~ -Darker$ ]]; then
      gsettings set org.cinnamon.theme name "'${GTKTHEME%er}'"
    else
      gsettings set org.cinnamon.theme name "'${GTKTHEME}'"
    fi
  fi

  if pacman -Qi gnome-shell > /dev/null 2>&1; then
    show_info "Setting GNOME GTK theme to ${GTKTHEME@Q}."
    gsettings set org.gnome.desktop.wm.preferences theme "'${GTKTHEME}'"
    if [[ "${GTKTHEME,,}" =~ dark ]]; then
      gsettings set org.gnome.desktop.interface color-scheme "'prefer-dark'"
    else
      gsettings set org.gnome.desktop.interface color-scheme "'default'"
    fi
    gsettings set org.gnome.desktop.interface gtk-theme "'${GTKTHEME}'"
    gnome-extensions enable "user-theme@gnome-shell-extensions.gcampax.github.com" || true
    gsettings set org.gnome.shell.extensions.user-theme name "'${GTKTHEME}'"
  fi

  if pacman -Qi plasma-desktop > /dev/null 2>&1; then
    show_info "Setting Plasma GTK theme to ${GTKTHEME@Q}."
    local qdb
    if qdb="$(_get_qdbus)"; then
      if "${qdb}" org.kde.KWin > /dev/null; then
        "${qdb}" org.kde.KWin /KWin reconfigure
      fi
    fi
  fi

  set_config_key_value "${HOME}/.xprofile" "export GTK_THEME" "${GTKTHEME}"
  set_config_key_value \
    "${HOME}/.config/environment.d/envvars.conf" "GTK_THEME" "${GTKTHEME}"
}
set_icon_theme {
  show_header "Setting desktop icon theme to ${ICONTHEME@Q}."

  if pacman -Qi cinnamon > /dev/null 2>&1; then
    show_info "Setting Cinnamon icon theme to ${ICONTHEME@Q}."
    gsettings set org.cinnamon.desktop.interface icon-theme "'${ICONTHEME}'"
  fi

  if pacman -Qi gnome-shell > /dev/null 2>&1; then
    show_info "Setting GNOME icon theme to ${ICONTHEME@Q}."
    gsettings set org.gnome.desktop.interface icon-theme "'${ICONTHEME}'"
  fi

  if [ -e /usr/lib/plasma-changeicons ]; then
    show_info "Setting Plasma icon theme to ${ICONTHEME@Q}."
    /usr/lib/plasma-changeicons "${ICONTHEME}"
  fi
}
execute_script() {
    local script="$1"
    local script_path="$script_directory/$script"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if [ -x "$script_path" ]; then
            env USE_PRESET=$use_preset  "$script_path"
        else
            echo "Failed to make script '$script' executable."
        fi
    else
        echo "Script '$script' not found in '$script_directory'."
    fi
}

install-package-helper() {
    # Set color variables for output messages
    OK="$(tput setaf 2)[OK]$(tput sgr0)"
    ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
    NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
    WARN="$(tput setaf 5)[WARN]$(tput sgr0)"
    CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
    ORANGE=$(tput setaf 166)
    YELLOW=$(tput setaf 3)
    RESET=$(tput sgr0)

    # Define log file if not already defined
    LOG="${LOG:-/var/log/paru_install.log}"

    # Function to log messages
    log_message() {
        echo -e "$1" | tee -a "$LOG"
    }

    # Check for existing AUR helper
    ISAUR=$(command -v yay || command -v paru)

    if [ -z "$ISAUR" ]; then
        print_message WARMNING "No AUR helper found."

        # Ask user which AUR helper to install
        echo "Select an AUR helper to install:"
        select AUR_HELPER in "yay" "paru" "Cancel"; do
            case "$AUR_HELPER" in
                yay)
                    CHOSEN_HELPER="yay"
                    break
                    ;;
                paru)
                    CHOSEN_HELPER="paru"
                    break
                    ;;
                Cancel)
                    print_message ERROR "Installation canceled by user."
                    return 1
                    ;;
                *)
                    print_message ERROR "Invalid selection."
                    ;;
            esac
        done

        # Install the chosen AUR helper
        print_message NOTE "Installing ${CHOSEN_HELPER} from AUR."
        git clone "https://aur.archlinux.org/${CHOSEN_HELPER}.git" || { print_message ERROR "Failed to clone ${CHOSEN_HELPER} from AUR."; exit 1; }
        cd "${CHOSEN_HELPER}" || { print_message ERROR "Failed to enter ${CHOSEN_HELPER} directory."; exit 1; }
        makepkg -si --noconfirm 2>&1 | tee -a "$LOG" || { print_message ERROR "Failed to install ${CHOSEN_HELPER} from AUR."; exit 1; }
        cd .. || exit
        rm -rf "${CHOSEN_HELPER}"
        ISAUR=$(command -v "$CHOSEN_HELPER")
        if [ -z "$ISAUR" ]; then
            print_message ERROR "${CHOSEN_HELPER} installation failed."
            exit 1
        fi
        print_message OK "${CHOSEN_HELPER} installed successfully."
    else
        print_message OK "Found existing AUR helper: ${ISAUR}"
    fi

    # Update system before proceeding
    print_message NOTE "Performing a full system update to avoid issues..."
    "$ISAUR" -Syu --noconfirm 2>&1 | tee -a "$LOG" || { print_message ERROR "Failed to update system."; exit 1; }

    print_message OK "System updated successfully."
    clear
}

pkg() {

    Qeq: base
    Qq : all pkgs
    Qmq: aur pkgs
    Qdq: only dep pkgs


}