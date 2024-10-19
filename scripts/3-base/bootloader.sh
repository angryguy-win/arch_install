#!/bin/bash
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

# Enable dry run mode for testing purposes (set to false to disable)
export DRY_RUN="${DRY_RUN:-false}"

configure_mkinitcpio() {
    print_message INFO "Configuring mkinitcpio"

    local mkinitcpio_conf="/mnt/etc/mkinitcpio.conf"
    local hooks="base udev autodetect modconf block filesystems keyboard fsck"
    local modules=""

    # Add KMS modules if needed
    if [ "$KMS" == "true" ]; then
        case "$DISPLAY_DRIVER" in
            "intel")  modules+="i915 "   ;;
            "amdgpu") modules+="amdgpu " ;;
            "ati")    modules+="radeon " ;;
            "nvidia" | "nvidia-lts" | "nvidia-dkms")
                modules+="nvidia nvidia_modeset nvidia_uvm nvidia_drm "
                ;;
            "nouveau") modules+="nouveau " ;;
        esac
    fi

    # Add LVM hook if needed
    [ "$LVM" == "true" ] && hooks+=" lvm2"

    # Add encryption hooks if needed
    if [ -n "$LUKS_PASSWORD" ]; then
        if [ "$BOOTLOADER" == "systemd" ] || [ "$GPT_AUTOMOUNT" == "true" ]; then
            hooks+=" sd-encrypt"
        else
            hooks+=" encrypt"
        fi
    fi

    execute_process "Updating mkinitcpio.conf" \
        --use-chroot \
        --error-message "Failed to update mkinitcpio.conf" \
        --success-message "Successfully updated mkinitcpio.conf" \
        "sed -i 's/^HOOKS=.*/HOOKS=($hooks)/' $mkinitcpio_conf" \
        "sed -i 's/^MODULES=.*/MODULES=($modules)/' $mkinitcpio_conf"

    if [ -n "$KERNELS_COMPRESSION" ]; then
        execute_process "Setting kernel compression" \
            --use-chroot \
            "sed -i 's/^#COMPRESSION=\"$KERNELS_COMPRESSION\"/COMPRESSION=\"$KERNELS_COMPRESSION\"/' $mkinitcpio_conf"
    fi

    execute_process "Regenerating initramfs" \
        --use-chroot \
        --error-message "Failed to regenerate initramfs" \
        --success-message "Successfully regenerated initramfs" \
        "mkinitcpio -P"
}

configure_grub() {
    print_message INFO "Configuring GRUB"

    execute_process "Installing GRUB packages" \
        --use-chroot \
        --error-message "Failed to install GRUB packages" \
        --success-message "Successfully installed GRUB packages" \
        "pacman -S --noconfirm grub dosfstools"

    local grub_default="/mnt/etc/default/grub"
    execute_process "Configuring GRUB" \
        --use-chroot \
        --error-message "Failed to configure GRUB" \
        --success-message "Successfully configured GRUB" \
        "sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/' $grub_default" \
        "sed -i 's/#GRUB_SAVEDEFAULT=\"true\"/GRUB_SAVEDEFAULT=\"true\"/' $grub_default" \
        "sed -i -E 's/GRUB_CMDLINE_LINUX_DEFAULT=\"(.*) quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\"/' $grub_default" \
        "sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"$CMDLINE_LINUX\"/' $grub_default" \
        "echo -e '\n# alis\nGRUB_DISABLE_SUBMENU=y' >> $grub_default"

    if [ "$BIOS_TYPE" == "uefi" ]; then
        execute_process "Installing GRUB for UEFI" \
            --use-chroot \
            "grub-install --target=x86_64-efi --bootloader-id=grub --efi-directory=$ESP_DIRECTORY --recheck"
    elif [ "$BIOS_TYPE" == "bios" ]; then
        execute_process "Installing GRUB for BIOS" \
            --use-chroot \
            "grub-install --target=i386-pc --recheck $DEVICE"
    fi

    execute_process "Generating GRUB config" \
        --use-chroot \
        "grub-mkconfig -o $BOOT_DIRECTORY/grub/grub.cfg"

    if [ "$SECURE_BOOT" == "true" ]; then
        execute_process "Configuring Secure Boot" \
            "mv {PreLoader,HashTool}.efi /mnt$ESP_DIRECTORY/EFI/grub" \
            "cp /mnt$ESP_DIRECTORY/EFI/grub/grubx64.efi /mnt$ESP_DIRECTORY/EFI/systemd/loader.efi" \
            --use-chroot \
            "efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux (PreLoader)\" --loader \"/EFI/grub/PreLoader.efi\""
    fi

    if [ "$VIRTUALBOX" == "true" ]; then
        execute_process "Configuring VirtualBox boot" \
            "echo -n \"\EFI\grub\grubx64.efi\" > /mnt$ESP_DIRECTORY/startup.nsh"
    fi
}

configure_systemd_boot() {
    print_message INFO "Configuring systemd-boot"

    execute_process "Installing systemd-boot" \
        --use-chroot \
        --error-message "Failed to install systemd-boot" \
        --success-message "Successfully installed systemd-boot" \
        "bootctl install"

    local loader_conf="/mnt$ESP_DIRECTORY/loader/loader.conf"
    execute_process "Configuring loader.conf" \
        "echo -e '# alis\ntimeout 5\ndefault archlinux.conf\neditor 0' > $loader_conf"

    local entry_dir="/mnt$ESP_DIRECTORY/loader/entries"
    mkdir -p "$entry_dir"

    create_systemd_boot_entry "linux"
    if [ -n "$KERNELS" ]; then
        for KERNEL in $KERNELS; do
            [[ "$KERNEL" =~ ^.*-headers$ ]] && continue
            create_systemd_boot_entry "$KERNEL"
        done
    fi

    if [ "$VIRTUALBOX" == "true" ]; then
        echo -n "\EFI\systemd\systemd-bootx64.efi" > "/mnt$ESP_DIRECTORY/startup.nsh"
    fi
}

create_systemd_boot_entry() {
    local KERNEL="$1"
    local MICROCODE=""
    [ -n "$INITRD_MICROCODE" ] && MICROCODE="initrd /$INITRD_MICROCODE"

    local entry_file="$entry_dir/arch-$KERNEL.conf"
    cat <<EOT > "$entry_file"
title Arch Linux ($KERNEL)
linux /vmlinuz-$KERNEL
$MICROCODE
initrd /initramfs-$KERNEL.img
options $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX
EOT

    local fallback_entry_file="$entry_dir/arch-$KERNEL-fallback.conf"
    cat <<EOT > "$fallback_entry_file"
title Arch Linux ($KERNEL, fallback)
linux /vmlinuz-$KERNEL
$MICROCODE
initrd /initramfs-$KERNEL-fallback.img
options $CMDLINE_LINUX_ROOT rw $CMDLINE_LINUX
EOT
}

configure_efistub() {
    print_message INFO "Configuring EFISTUB"

    execute_process "Installing efibootmgr" \
        --use-chroot \
        --error-message "Failed to install efibootmgr" \
        --success-message "Successfully installed efibootmgr" \
        "pacman -S --noconfirm efibootmgr"

    create_efistub_entry "linux"
    if [ -n "$KERNELS" ]; then
        for KERNEL in $KERNELS; do
            [[ "$KERNEL" =~ ^.*-headers$ ]] && continue
            create_efistub_entry "$KERNEL"
        done
    fi
}

create_efistub_entry() {
    local KERNEL="$1"
    local MICROCODE=""
    [ -n "$INITRD_MICROCODE" ] && MICROCODE="initrd=\\$INITRD_MICROCODE"

    if [ "$UKI" == "true" ]; then
        execute_process "Creating EFISTUB entry for $KERNEL" \
            --use-chroot \
            "efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL)\" --loader \"EFI\\linux\\archlinux-$KERNEL.efi\" --unicode --verbose" \
            "efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL fallback)\" --loader \"EFI\\linux\\archlinux-$KERNEL-fallback.efi\" --unicode --verbose"
    else
        execute_process "Creating EFISTUB entry for $KERNEL" \
            --use-chroot \
            "efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL)\" --loader /vmlinuz-$KERNEL --unicode \"$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\\initramfs-$KERNEL.img\" --verbose" \
            "efibootmgr --unicode --disk $DEVICE --part 1 --create --label \"Arch Linux ($KERNEL fallback)\" --loader /vmlinuz-$KERNEL --unicode \"$CMDLINE_LINUX $CMDLINE_LINUX_ROOT rw $MICROCODE initrd=\\initramfs-$KERNEL-fallback.img\" --verbose"
    fi
}

main() {
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