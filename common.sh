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
function configuration() {
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
        local FILE="${MNT_DIR}/var/log/alis/$ALIS_CONF_FILE"

        mkdir -p "${MNT_DIR}"/var/log/alis
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
    if [ -f "$ALIS_LOG_FILE" ]; then
        local SOURCE_FILE="$ALIS_LOG_FILE"
        local FILE="${MNT_DIR}/var/log/alis/$ALIS_LOG_FILE"

        mkdir -p "${MNT_DIR}"/var/log/alis
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
function sanitize_variables() {
    DEVICE=$(sanitize_variable "$DEVICE")
    PARTITION_MODE=$(sanitize_variable "$PARTITION_MODE")
    PARTITION_CUSTOM_PARTED_UEFI=$(sanitize_variable "$PARTITION_CUSTOM_PARTED_UEFI")
    PARTITION_CUSTOM_PARTED_BIOS=$(sanitize_variable "$PARTITION_CUSTOM_PARTED_BIOS")
    FILE_SYSTEM_TYPE=$(sanitize_variable "$FILE_SYSTEM_TYPE")
    SWAP_SIZE=$(sanitize_variable "$SWAP_SIZE")
    KERNELS=$(sanitize_variable "$KERNELS")
    KERNELS_COMPRESSION=$(sanitize_variable "$KERNELS_COMPRESSION")
    KERNELS_PARAMETERS=$(sanitize_variable "$KERNELS_PARAMETERS")
    AUR_PACKAGE=$(sanitize_variable "$AUR_PACKAGE")
    DISPLAY_DRIVER=$(sanitize_variable "$DISPLAY_DRIVER")
    DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL=$(sanitize_variable "$DISPLAY_DRIVER_HARDWARE_VIDEO_ACCELERATION_INTEL")
    SYSTEMD_HOMED_STORAGE=$(sanitize_variable "$SYSTEMD_HOMED_STORAGE")
    SYSTEMD_HOMED_STORAGE_LUKS_TYPE=$(sanitize_variable "$SYSTEMD_HOMED_STORAGE_LUKS_TYPE")
    BOOTLOADER=$(sanitize_variable "$BOOTLOADER")
    CUSTOM_SHELL=$(sanitize_variable "$CUSTOM_SHELL")
    DESKTOP_ENVIRONMENT=$(sanitize_variable "$DESKTOP_ENVIRONMENT")
    DISPLAY_MANAGER=$(sanitize_variable "$DISPLAY_MANAGER")
    SYSTEMD_UNITS=$(sanitize_variable "$SYSTEMD_UNITS")

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

logs() {
### Set up logging ###
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log")
}
# @description Execute a process with retries and logging
# @param $1 The description of the process
# @param $@ The command to execute  
execute_process() {
    local description="$1"
    shift
    local error_message=""
    local success_message=""
    local critical=false
    local debug=false
    local max_attempts=3
    local delay=5
    local network_dependent=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --error-message) error_message="$2"; shift 2 ;;
            --success-message) success_message="$2"; shift 2 ;;
            --critical) critical=true; shift ;;
            --debug) debug=true; shift ;;
            --network-dependent) network_dependent=true; shift ;;
            *) break ;;
        esac
    done

    local commands=("$@")
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if $debug; then
            print_message DEBUG "Executing: ${commands[*]}"
        fi

        if [ "$DRY_RUN" = "true" ]; then
            print_message ACTION "[DRY RUN] Would execute: ${commands[*]}"
            return 0
        fi

        if ! "${commands[@]}"; then
            if $network_dependent && [ $attempt -lt $max_attempts ]; then
                print_message WARNING "Attempt $attempt failed. Retrying in $delay seconds..."
                sleep $delay
                attempt=$((attempt + 1))
                continue
            fi
            
            if [ -n "$error_message" ]; then
                print_message ERROR "$error_message"
            else
                print_message ERROR "Failed to execute: ${commands[*]}"
            fi

            if $critical; then
                handle_critical_error "Critical operation failed: $description"
            fi

            return 1
        else
            break
        fi
    done

    if [ -n "$success_message" ]; then
        print_message OK "$success_message"
    fi

    return 0
}

CHECKPOINT_FILE="/tmp/install_checkpoint"

save_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
}


###-----------------------------------###
resume_from_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        local checkpoint=$(cat "$CHECKPOINT_FILE")
        print_message INFO "Resuming from checkpoint: $checkpoint"
        case "$checkpoint" in
            partitioning) partitioning ;;
            formatting) formatting ;;
            base_install) base_install ;;
            # ... other stages ...
            *) print_message WARNING "Unknown checkpoint: $checkpoint. Starting from the beginning." ;;
        esac
    else
        print_message INFO "No checkpoint found. Starting from the beginning."
    fi
}

# In your main installation flow:
main() {
    resume_from_checkpoint

    # Normal installation flow
    partitioning && save_checkpoint "partitioning"
    formatting && save_checkpoint "formatting"
    base_install && save_checkpoint "base_install"
    # ... other stages ...

    # Clean up checkpoint file on successful completion
    rm -f "$CHECKPOINT_FILE"
}

CHECKPOINT_FILE="/tmp/arch_install_checkpoint"

save_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
}

resume_from_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        local checkpoint=$(cat "$CHECKPOINT_FILE")
        print_message INFO "Resuming from checkpoint: $checkpoint"
        case "$checkpoint" in
            partitioning) partitioning ;;
            formating) formating ;;
            # Add other stages here
            *) print_message WARNING "Unknown checkpoint: $checkpoint. Starting from the beginning." ;;
        esac
    else
        print_message INFO "No checkpoint found. Starting from the beginning."
    fi
}

formating() {
    # Your existing formating function code here
    # ...

    # At the end of the function:
    save_checkpoint "formating"
}

# In your main function:
main() {
    resume_from_checkpoint

    # Your normal installation flow
    partitioning && save_checkpoint "partitioning"
    formating
    # Other stages...

    # Clean up checkpoint file on successful completion
    rm -f "$CHECKPOINT_FILE"
}


save_checkpoint() {
    echo "stage=$1;device=$DEVICE;partition_root=$partition_root" > "$CHECKPOINT_FILE"
}

PARTITION_CHECKPOINT="/tmp/partition_checkpoint"
FORMAT_CHECKPOINT="/tmp/format_checkpoint"
--
save_partition_checkpoint() {
    echo "$1" > "$PARTITION_CHECKPOINT"
}
--
save_format_checkpoint() {
    echo "$1" > "$FORMAT_CHECKPOINT"
}
--
save_checkpoint() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$CHECKPOINT_FILE"
}

resume_from_checkpoint() {
    if [ -f "$CHECKPOINT_FILE" ]; then
        local checkpoint=$(cat "$CHECKPOINT_FILE")
        print_message INFO "Checkpoint found: $checkpoint"
        read -p "Do you want to resume from this checkpoint? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Resume logic here
            case "$checkpoint" in
                partitioning)
                    print_message INFO "Resuming from partitioning"
                    formatting
                    base_install
                    generate_fstab
                    # ... continue with remaining steps
                    ;;
                formatting)
                    print_message INFO "Resuming from formatting"
                    base_install
                    generate_fstab
                    # ... continue with remaining steps
                    ;;
                base_install)
                    print_message INFO "Resuming from base install"
                    generate_fstab
                    # ... continue with remaining steps
                    ;;
                # Add more cases for other checkpoints
                *)
                    print_message WARNING "Unknown checkpoint: $checkpoint. Starting from the beginning."
                    start_fresh_installation
                    ;;
            esac
        else
            print_message INFO "Starting fresh installation"
            rm -f "$CHECKPOINT_FILE"
            start_fresh_installation
        fi
    else
        print_message INFO "No checkpoint found. Starting fresh installation."
        start_fresh_installation
    fi
}

start_fresh_installation() {
    partitioning

    formatting
    base_install
    generate_fstab
    # ... continue with all installation steps
}

save_checkpoint() {
    echo "$1" > "$CHECKPOINT_FILE"
    log_message "Checkpoint saved: $1"
}

###-----------------------------------###

sanitize() {
    local VARIABLE="$1"
    local VARIABLE=$(echo "$VARIABLE" | sed "s/![^ ]*//g") # remove disabled
    local VARIABLE=$(echo "$VARIABLE" | sed -r "s/ {2,}/ /g") # remove unnecessary white spaces
    local VARIABLE=$(echo "$VARIABLE" | sed 's/^[[:space:]]*//') # trim leading
    local VARIABLE=$(echo "$VARIABLE" | sed 's/[[:space:]]*$//') # trim trailing
    echo "$VARIABLE"
}

trim() {
    local VARIABLE="$1"
    local VARIABLE=$(echo "$VARIABLE" | sed 's/^[[:space:]]*//') # trim leading
    local VARIABLE=$(echo "$VARIABLE" | sed 's/[[:space:]]*$//') # trim trailing
    echo "$VARIABLE"
}

check_variables_value() {
    local NAME="$1"
    local VALUE="$2"
    if [ -z "$VALUE" ]; then
        echo "$NAME environment variable must have a value."
        exit 1
    fi
}

check_variables_boolean() {
    local NAME="$1"
    local VALUE="$2"
    check_variables_list "$NAME" "$VALUE" "true false" "true" "true"
}

check_variables_list() {
    local NAME="$1"
    local VALUE="$2"
    local VALUES="$3"
    local REQUIRED="$4"
    local SINGLE="$5"

    if [ "$REQUIRED" == "" ] || [ "$REQUIRED" == "true" ]; then
        check_variables_value "$NAME" "$VALUE"
    fi

    if [[ ("$SINGLE" == "" || "$SINGLE" == "true") && "$VALUE" != "" && "$VALUE" =~ " " ]]; then
        echo "$NAME environment variable value [$VALUE] must be a single value of [$VALUES]."
        exit 1
    fi

    if [ "$VALUE" != "" ] && [ -z "$(echo "$VALUES" | grep -F -w "$VALUE")" ]; then #SC2143
        echo "$NAME environment variable value [$VALUE] must be in [$VALUES]."
        exit 1
    fi
}

check_variables_equals() {
    local NAME1="$1"
    local NAME2="$2"
    local VALUE1="$3"
    local VALUE2="$4"
    if [ "$VALUE1" != "$VALUE2" ]; then
        echo "$NAME1 and $NAME2 must be equal [$VALUE1, $VALUE2]."
        exit 1
    fi
}

check_variables_size() {
    local NAME="$1"
    local SIZE_EXPECT="$2"
    local SIZE="$3"
    if [ "$SIZE_EXPECT" != "$SIZE" ]; then
        echo "$NAME array size [$SIZE] must be [$SIZE_EXPECT]."
        exit 1
    fi
}

configure_network() {
    if [ -n "$WIFI_INTERFACE" ]; then
        iwctl --passphrase "$WIFI_KEY" station "$WIFI_INTERFACE" connect "$WIFI_ESSID"
        sleep 10
    fi

    # only one ping -c 1, ping gets stuck if -c 5
    if ! ping -c 1 -i 2 -W 5 -w 30 "$PING_HOSTNAME"; then
        echo "Network ping check failed. Cannot continue."
        exit 1
    fi
}

pacman_uninstall() {
    local ERROR="true"
    local PACKAGES=()
    set +e
    IFS=' ' read -ra PACKAGES <<< "$1"
    local PACKAGES_UNINSTALL=()
    for PACKAGE in "${PACKAGES[@]}"
    do
        execute_sudo "pacman -Qi $PACKAGE > /dev/null 2>&1"
        local PACKAGE_INSTALLED=$?
        if [ $PACKAGE_INSTALLED == 0 ]; then
            local PACKAGES_UNINSTALL+=("$PACKAGE")
        fi
    done
    if [ -z "${PACKAGES_UNINSTALL[*]}" ]; then
        return
    fi
    local COMMAND="pacman -Rdd --noconfirm ${PACKAGES_UNINSTALL[*]}"
    if execute_sudo "$COMMAND"; then
        local ERROR="false"
    fi
    set -e
    if [ "$ERROR" == "true" ]; then
        exit 1
    fi
}

pacman_install() {
    local ERROR="true"
    local PACKAGES=()
    set +e
    IFS=' ' read -ra PACKAGES <<< "$1"
    for VARIABLE in {1..5}
    do
        local COMMAND="pacman -Syu --noconfirm --needed ${PACKAGES[*]}"
       if execute_sudo "$COMMAND"; then
            local ERROR="false"
            break
        else
            sleep 10
        fi
    done
    set -e
    if [ "$ERROR" == "true" ]; then
        exit 1
    fi
}

aur_install() {
    local ERROR="true"
    local PACKAGES=()
    set +e
    which "$AUR_COMMAND"
    if [ "$AUR_COMMAND" != "0" ]; then
        aur_command_install "$USER_NAME" "$AUR_PACKAGE"
    fi
    IFS=' ' read -ra PACKAGES <<< "$1"
    for VARIABLE in {1..5}
    do
        local COMMAND="$AUR_COMMAND -Syu --noconfirm --needed ${PACKAGES[*]}"
        if execute_aur "$COMMAND"; then
            local ERROR="false"
            break
        else
            sleep 10
        fi
    done
    set -e
    if [ "$ERROR" == "true" ]; then
        return
    fi
}

aur_command_install() {
    pacman_install "git"
    local USER_NAME="$1"
    local COMMAND="$2"
    execute_aur "rm -rf /home/$USER_NAME/.alis && mkdir -p /home/$USER_NAME/.alis/aur && cd /home/$USER_NAME/.alis/aur && git clone https://aur.archlinux.org/${COMMAND}.git && (cd $COMMAND && makepkg -si --noconfirm) && rm -rf /home/$USER_NAME/.alis"
}

execute_sudo() {
    local COMMAND="$1"
    if [ "$SYSTEM_INSTALLATION" == "true" ]; then
        arch-chroot "${MNT_DIR}" bash -c "$COMMAND"
    else
        sudo bash -c "$COMMAND"
    fi
}

execute_step() {
    local STEP="$1"
    eval "$STEP"
}

