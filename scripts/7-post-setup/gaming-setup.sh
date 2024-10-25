#!/bin/bash
# Gaming Setup Script for Arch Linux
# Author: ssnow
# Date: 2024
# Description: Installs and configures gaming-related software and drivers

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Initialize variables
export DRY_RUN="${DRY_RUN:-false}"
print_message INFO "DRY_RUN in $(basename "$0") is set to: $DRY_RUN"

# Gaming-related package groups
declare -A GAMING_PACKAGES=(
    [base]="steam lutris wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader"
    [proton]="proton-ge-custom wine-gecko wine-mono gamemode lib32-gamemode"
    [tools]="mangohud lib32-mangohud goverlay"
    [emulators]="retroarch libretro-core-info"
    [performance]="gamemode lib32-gamemode"
)

# Function to install gaming drivers based on GPU
install_gaming_drivers() {
    local gpu_info
    gpu_info=$(gpu_type)
    print_message INFO "Detected GPU: $gpu_info"

    execute_process "Gaming Drivers Installation" \
        --debug \
        --critical \
        --error-message "Failed to install gaming drivers" \
        --success-message "Gaming drivers installed successfully" \
        case "$gpu_info" in
            *NVIDIA*|*GeForce*)
                "pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader"
                ;;
            *AMD*|*ATI*)
                "pacman -S --noconfirm --needed lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader"
                ;;
            *Intel*)
                "pacman -S --noconfirm --needed lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader"
                ;;
        esac
}

# Function to install gaming packages
install_gaming_packages() {
    local package_group=$1
    local packages="${GAMING_PACKAGES[$package_group]}"

    execute_process "Installing $package_group packages" \
        --debug \
        --error-message "Failed to install $package_group packages" \
        --success-message "$package_group packages installed successfully" \
        "pacman -S --noconfirm --needed $packages"
}

# Function to install and configure ProtonGE
setup_proton() {
    execute_process "ProtonGE Setup" \
        --debug \
        --error-message "ProtonGE setup failed" \
        --success-message "ProtonGE setup completed" \
        "mkdir -p ~/.steam/root/compatibilitytools.d" \
        "curl -L 'https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton.tar.gz' -o /tmp/proton-ge.tar.gz" \
        "tar -xzf /tmp/proton-ge.tar.gz -C ~/.steam/root/compatibilitytools.d/" \
        "rm /tmp/proton-ge.tar.gz"
}

# Function to configure gaming optimizations
configure_gaming_optimizations() {
    execute_process "Gaming Optimizations" \
        --debug \
        --error-message "Failed to configure gaming optimizations" \
        --success-message "Gaming optimizations configured" \
        "systemctl --user enable gamemoded" \
        "echo 'MANGOHUD=1' >> ~/.bashrc" \
        "echo 'MANGOHUD_CONFIG=cpu_temp,gpu_temp,vram,ram,fps,frame_timing=1' >> ~/.bashrc"
}
aur_gaming_packages() {
    execute_process "AUR Gaming Packages" \
        --debug \
        --error-message "Failed to install AUR gaming packages" \
        --success-message "AUR gaming packages installed" \
        "yay -S --noconfirm --needed heroic-games-launcher-bin bottles discord_arch_electron"
}
# Main function
main() {
    process_init "Gaming Setup"
    print_message INFO "Starting gaming environment setup"

    # Install gaming drivers
    install_gaming_drivers || return $?

    # Install all gaming package groups
    for group in "${!GAMING_PACKAGES[@]}"; do
        install_gaming_packages "$group" || return $?
    done

    # Setup ProtonGE
    setup_proton || return $?

    # Configure optimizations
    configure_gaming_optimizations || return $?

    print_message INFO "Installing additional AUR packages"
    install-package-helper || return $?
    aur_gaming_packages || return $?

    process_end $?
}

# Run the script
main "$@"
exit $?