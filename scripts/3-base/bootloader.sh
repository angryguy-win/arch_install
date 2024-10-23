#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2001,SC2155,SC2153,SC2143
# SC2034: foo appears unused. Verify it or export it.
# SC2001: See if you can use ${variable//search/replace} instead.
# SC2155 Declare and assign separately to avoid masking return values
# SC2153: Possible Misspelling: MYVARIABLE may not be assigned. Did you mean MY_VARIABLE?
# SC2143: Use grep -q instead of comparing output with [ -n .. ].
# Configure Bootloader Script
# Author: ssnow
# Date: 2024
# Description: Configure bootloader for Arch Linux installation

set -eo pipefail

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
set -o errtrace
set -o functrace
set_error_trap
# Get the current stage/script context
get_current_context
# Enable dry run mode for testing purposes (set to false to disable)
export DRY_RUN="${DRY_RUN:-false}"

configure_mkinitcpio() {
    print_message INFO "Configuring mkinitcpio"

    local mkinitcpio_conf="/mnt/etc/mkinitcpio.conf"
    local hooks="base udev autodetect modconf block filesystems keyboard fsck"
    local modules=""
    local commands=()

    # Add KMS modules if needed
    if [ "$KMS" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "intel")  modules+="i915 "   ;;
            "amdgpu") modules+="amdgpu " ;;
            "ati")    modules+="radeon " ;;
            "nvidia" | "nvidia-lts" | "nvidia-dkms")
                      modules+="nvidia nvidia_modeset nvidia_uvm nvidia_drm " ;;
            "nouveau") modules+="nouveau " ;;
        esac
    fi

    # Add LVM hook if needed
    [ "$LVM" == "true" ] && hooks+=" lvm2"

    # Add encryption hooks if needed
    if [ "$LUKS" == "true" ]; then
        if [ "$BOOTLOADER" == "systemd" ] || [ "$GPT_AUTOMOUNT" == "true" ]; then
            hooks+=" sd-encrypt"
        else
            hooks+=" encrypt"
        fi
    fi

    print_message ACTION "Updating mkinitcpio.conf"
    commands+=("sed -i 's/^HOOKS=.*/HOOKS=($hooks)/' $mkinitcpio_conf")
    commands+=("sed -i 's/^MODULES=.*/MODULES=($modules)/' $mkinitcpio_conf")

    if [ -n "$KERNELS_COMPRESSION" ]; then
        print_message ACTION "Setting kernel compression"
        commands+=("sed -i 's/^#COMPRESSION=\"$KERNELS_COMPRESSION\"/COMPRESSION=\"$KERNELS_COMPRESSION\"/' $mkinitcpio_conf")
    fi
    print_message ACTION "Regenerating initramfs"
    commands+=("mkinitcpio -P")

    execute_process "Configure mkinitcpio" \
        --use-chroot \
        --error-message "Failed to configure mkinitcpio" \
        --success-message "Successfully configured mkinitcpio" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "configure_mkinitcpio" \
        "${commands[@]}"
}

configure_grub() {
    local commands=()
    local grub_default

    print_message INFO "Configuring GRUB"

    print_message ACTION "Installing GRUB packages"
    commands+=("pacman -S --noconfirm grub dosfstools")

    grub_default="/mnt/etc/default/grub"
    print_message ACTION "Configuring GRUB"
    commands+=("sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' $grub_default")
    commands+=("sed -i 's/#GRUB_SAVEDEFAULT=\"true\"/GRUB_SAVEDEFAULT=\"true\"/' $grub_default")
    commands+=("sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*) quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\"/' $grub_default")
    commands+=("sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"$CMDLINE_LINUX\"/' $grub_default")
    commands+=("echo -e '\n# alis\nGRUB_DISABLE_SUBMENU=y' >> $grub_default")

    if [ "$BIOS_TYPE" == "uefi" ]; then
        print_message ACTION "Installing GRUB for UEFI"
        commands+=("grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=$ESP_DIRECTORY --recheck")
    elif [ "$BIOS_TYPE" == "bios" ]; then
        print_message ACTION "Installing GRUB for BIOS"
        commands+=("grub-install --target=i386-pc --recheck $DEVICE")
    fi

    print_message ACTION "Generating GRUB config"
    commands+=("grub-mkconfig -o $BOOT_DIRECTORY/grub/grub.cfg")

    if [ "$SECURE_BOOT" == "true" ]; then
        print_message ACTION "Configuring Secure Boot"
        commands+=("mv {PreLoader,HashTool}.efi /mnt$ESP_DIRECTORY/EFI/grub")
        commands+=("cp /mnt$ESP_DIRECTORY/EFI/grub/grubx64.efi /mnt$ESP_DIRECTORY/EFI/systemd/loader.efi")
        commands+=("efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux (PreLoader)\" --loader \"/EFI/grub/PreLoader.efi\"")
    fi

    execute_process "Configure GRUB" \
        --use-chroot \
        --error-message "Failed to configure GRUB" \
        --success-message "Successfully configured GRUB" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "configure_grub" \
        "${commands[@]}"
}

configure_systemd_boot() {
    local commands=()
    local loader_conf
    local entry_dir

    print_message INFO "Configuring systemd-boot"

    print_message ACTION "Installing systemd-boot"
    commands+=("bootctl install")

    loader_conf="/mnt$ESP_DIRECTORY/loader/loader.conf"
    print_message ACTION "Configuring loader.conf"
    commands+=("echo -e '# alis\ntimeout 5\ndefault archlinux.conf\neditor 0' > $loader_conf")

    entry_dir="/mnt$ESP_DIRECTORY/loader/entries"
    commands+=("mkdir -p $entry_dir")

    create_systemd_boot_entry linux
    if [ -n "$KERNELS" ]; then
        for KERNEL in $KERNELS; do
            [[ "$KERNEL" =~ ^.*-headers$ ]] && continue
            create_systemd_boot_entry $KERNEL
        done
    fi


    execute_process "Configure systemd-boot" \
        --use-chroot \
        --error-message "Failed to configure systemd-boot" \
        --success-message "Successfully configured systemd-boot" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "configure_systemd_boot" \
        "${commands[@]}"
}

create_systemd_boot_entry() {
    local KERNEL="$1"
    local commands=()
    local MICROCODE=""
    local entry_file="$entry_dir/arch-$KERNEL.conf"
    local fallback_entry_file="$entry_dir/arch-$KERNEL-fallback.conf"

    [ -n "$INITRD_MICROCODE" ] && MICROCODE="initrd /$INITRD_MICROCODE"

    # Create the main entry file
    commands+=("{
        echo \"title Arch Linux ($KERNEL)\"
        echo \"linux /vmlinuz-$KERNEL\"
        echo \"$MICROCODE\"
        echo \"initrd /initramfs-$KERNEL.img\"
        echo \"options $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX\"
    } > $entry_file")

    # Create the fallback entry file
    commands+=("{
        echo \"title Arch Linux ($KERNEL, fallback)\"
        echo \"linux /vmlinuz-$KERNEL\"
        echo \"$MICROCODE\"
        echo \"initrd /initramfs-$KERNEL-fallback.img\"
        echo \"options $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX\"
    } > \"$fallback_entry_file\"")

    execute_process "Creating systemd-boot entry for $KERNEL" \
        --use-chroot \
        --error-message "Failed to create systemd-boot entry for $KERNEL" \
        --success-message "Successfully created systemd-boot entry for $KERNEL" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "create_systemd_boot_entry" \
        "${commands[@]}"
}

configure_efistub() {
    local commands=()

    print_message INFO "Configuring EFISTUB"

    print_message ACTION "Installing efibootmgr"
    commands+=("pacman -S --noconfirm efibootmgr")

    create_efistub_entry linux
    if [ -n "$KERNELS" ]; then
        for KERNEL in $KERNELS; do
            [[ "$KERNEL" =~ ^.*-headers$ ]] && continue
            create_efistub_entry $KERNEL
        done
    fi

    execute_process "Configure EFISTUB" \
        --use-chroot \
        --error-message "Failed to configure EFISTUB" \
        --success-message "Successfully configured EFISTUB" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "configure_efistub" \
        "${commands[@]}"
}

create_efistub_entry() {
    local KERNEL="$1"
    local commands=()
    local MICROCODE=""
    [ -n "$INITRD_MICROCODE" ] && MICROCODE="initrd=\\$INITRD_MICROCODE"

    if [ "$UKI" == "true" ]; then
        print_message ACTION "Creating EFISTUB entry for $KERNEL"
        commands+=("efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL)\" --loader \"EFI\\linux\\archlinux-$KERNEL.efi\" --unicode --verbose")
        commands+=("efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL fallback)\" --loader \"EFI\\linux\\archlinux-$KERNEL-fallback.efi\" --unicode --verbose")
    else
        print_message ACTION "Creating EFISTUB entry for $KERNEL"
        commands+=("efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL)\" --loader /vmlinuz-$KERNEL --unicode \"$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\\initramfs-$KERNEL.img\" --verbose")
        commands+=("efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL fallback)\" --loader /vmlinuz-$KERNEL --unicode \"$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\\initramfs-$KERNEL-fallback.img\" --verbose")
    fi

    execute_process "Creating EFISTUB entry for $KERNEL" \
        --use-chroot \
        --error-message "Failed to create EFISTUB entry for $KERNEL" \
        --success-message "Successfully created EFISTUB entry for $KERNEL" \
        --checkpoint-step "$CURRENT_STAGE" "$CURRENT_SCRIPT" "create_efistub_entry" \
        "${commands[@]}"
}

main() {
    check_checkpoint "$CURRENT_STAGE" "$CURRENT_SCRIPT" "main" "0"
    process_init "Configure Bootloader $BOOTLOADER"
    print_message INFO "Starting bootloader configuration process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    configure_mkinitcpio || { print_message ERROR "mkinitcpio configuration failed"; return 1; }

    case "$BOOTLOADER" in
        "grub")
            configure_grub || { print_message ERROR "GRUB configuration failed"; return 1; }
            ;;
        "systemd")
            configure_systemd_boot || { print_message ERROR "systemd-boot configuration failed"; return 1; }
            ;;
        "efistub")
            configure_efistub || { print_message ERROR "EFISTUB configuration failed"; return 1; }
            ;;
        *)
            print_message ERROR "Unknown bootloader: $BOOTLOADER"
            return 1
            ;;
    esac

    print_message OK "Bootloader configuration completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?
