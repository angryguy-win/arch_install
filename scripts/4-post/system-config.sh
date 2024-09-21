#!/bin/bash
# System Config Script
# Author: ssnow
# Date: 2024
# Description: System config script for Arch Linux installation

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

gpu_setup() {
   gpu_type=$(lspci | grep -E "VGA|3D|Display")
    # Graphics Drivers find and install
    if printf "%s" "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
        print_message ACTION "Installing NVIDIA drivers: nvidia-lts"
        command="pacman -S --noconfirm --needed nvidia-lts"
    elif printf "%s" "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
        print_message ACTION "Installing AMD drivers: xf86-video-amdgpu"
        command="pacman -S --noconfirm --needed xf86-video-amdgpu"
    elif printf "%s" "${gpu_type}" | grep -E "Integrated Graphics Controller"; then
        print_message ACTION "Installing Intel drivers:"
        command="pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa"
    elif printf "%s" "${gpu_type}" | grep -E "Intel Corporation UHD"; then
        print_message ACTION "Installing Intel UHD drivers:"
        command="pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa"
    else
        print_message WARNING "No matching GPU type found. Skipping driver installation."
        return 0
    fi
    print_message DEBUG "GPU type: ${gpu_type}"

    execute_process "GPU Setup" \
        --use-chroot \
        --critical \
        --error-message "GPU setup failed" \
        --success-message "GPU setup completed" \
        "${command}"
}
system_config() {

    print_message DEBUG "Chroot operations: $HOSTNAME, $LOCALE, $TIMEZONE, $KEYMAP, $USERNAME, $PASSWORD"
    execute_process "System config" \
        --use-chroot \
        --error-message "System config failed" \
        --success-message "System config completed" \
        "echo '$HOSTNAME' > /etc/hostname" \
        "echo '$LOCALE UTF-8' > /etc/locale.gen" \
        "locale-gen" \
        "echo 'LANG=$LOCALE' > /etc/locale.conf" \
        "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime" \
        "echo 'KEYMAP=$KEYMAP' > /etc/vconsole.conf" \
        "useradd -m -G wheel -s /bin/bash $USERNAME" \
        "echo 'root:$PASSWORD' | chpasswd" \
        "echo '$USERNAME:$PASSWORD' | chpasswd" \
        "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers"

}

main() {
    process_init "System Config"
    show_logo "System Config"
    print_message INFO "Starting system config process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    gpu_setup || { print_message ERROR "GPU setup failed"; return 1; }
    system_config || { print_message ERROR "System config process failed"; return 1; }

    print_message OK "System config process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?