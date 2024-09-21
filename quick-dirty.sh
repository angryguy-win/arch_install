#!/bin/bash
# Quick and dirty Arch Linux installation script
# This script is for a fresh install of Arch Linux
# This Script has NO WARRANTY and NO SUPPORT what so ever
# NO Error checking is done it will break at every error
# so make sure all your variable are set correctly
# and all your packages are valid
# Author: ssnow
# Date: 2024-07-13
# Version: 0.1
# License: MIT  


# Set global debug mode (can be overridden by command line arguments)
# if you want to risk it you can remove the set -e to plow through errors
set -eo pipefail

# Configuration variables
#@description COUNTRY_ISO is the ISO of the country you are installing in
#@note Set your variables correctly here:
# mistake here could give you a bad day use whit caution!
COUNTRY_ISO="CA"
DEVICE="/dev/nvme0n1"
PARTITION_BIOSBOOT="/dev/nvme0n1p1"
PARTITION_EFI="/dev/nvme0n1p2"
PARTITION_ROOT="/dev/nvme0n1p3"
PARTITION_HOME="/dev/nvme0n1p4"
PARTITION_SWAP="/dev/nvme0n1p5"
MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Toronto"
KEYMAP="us"
USERNAME="user"
PASSWORD="changeme"
HOSTNAME="hostname"
MICROCODE="intel"
GPU_DRIVER="nvidia"
TERMINAL="alacritty"
DISPLAY_MANAGER="gdm"


# Define packages to install
# @description PACKAGE_GROUPS is an associative array that holds the packages to be installed for each group
# @example PACKAGE_GROUPS=( ["base"]="eza fzf zoxide bat exa" )
# @note You can add more or less groups as needed YOU MUST follow the format
declare -A PACKAGE_GROUPS
PACKAGE_GROUPS=(
    ["base"]="eza fzf zoxide bat exa"
    ["system_tools"]="reflector openssh rsync"
    ["boot"]="plymouth grub os-prober"
    ["bluetooth"]="bluez bluez-utils"
    ["audio"]="pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack"
    ["utilities"]="fastfetch ntp cronie ${TERMINAL} kitty thunar"
    ["browser"]="firefox"
    ["desktop"]="gnome gnome-tweaks gdm"
    ["development"]="git vim neovim"
    ["office"]="libreoffice-fresh pinta"
    ["multimedia"]="vlc"
    ["communication"]="discord thunderbird"
    ["security"]="bitwarden"
    ["networking"]="networkmanager network-manager-applet dhclient"
    ["printer"]="cups"
    ["scanner"]=""
    ["virtualization"]="qemu virt-manager"
    ["containerization"]="docker"
    ["fonts"]="terminus-font ttf-font-awesome ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd ttf-meslo-nerd ttf-firacode-nerd ttf-nerd-fonts-symbols-common"
    ["filesystem"]="btrfs-progs dosfstools ntfs-3g"
    ["xdg"]="xdg-user-dirs"
    ["theme"]="papirus-icon-theme"
    ["gaming"]="steam lutris"
)
# User-configurable options
# Add more or less groups as needed
# @description Install groups are the groups of packages that will be installed
# @note You can add more or less groups as needed YOU MUST follow the format
INSTALL_GROUPS=(
    "base" 
    "bluetooth" 
    "audio" 
    "utilities" 
    "browser" 
    "desktop" 
    "development" 
    "office" 
    "multimedia" 
    "communication" 
    "security" 
    "networking" 
    "printer"  
    "fonts" 
    "filesystem" 
    "xdg"
)  # Default groups

# Function to print messages
# @description print_message is a function that prints a message to the console
# @param $1 The type of message to print
# @param $* The message to print
# @note This function is used to print messages to the console
print_message() {
    local type=$1
    shift
    printf %s "[$type] $*\n"
}
# Function to execute commands with error handling
# @description execute_process is a function that executes commands with error handling
# @param $1 The name of the process to execute
# @param $* The commands to execute
# @note This function is used to execute commands with error handling
execute_process() {
    local process_name="$1"
    shift
    local use_chroot=false
    local debug=false
    local error_message="Process failed"
    local success_message="Process completed successfully"

    while [[ "$1" == --* ]]; do
        case "$1" in
            --use-chroot) use_chroot=true; shift ;;
            --debug) debug=true; shift ;;
            --error-message) error_message="$2"; shift 2 ;;
            --success-message) success_message="$2"; shift 2 ;;
            *) printf %s "Unknown option: $1"; return 1 ;;
        esac
    done

    print_message INFO "Starting: $process_name"

    local commands=("$@")
    for cmd in "${commands[@]}"; do
        if [[ "$debug" == true ]]; then
            print_message DEBUG "Executing: $cmd"
        fi

        if [[ "$use_chroot" == true ]]; then
            if ! arch-chroot /mnt /bin/bash -c "$cmd"; then
                print_message ERROR "$error_message: $cmd"
                return 1
            fi
        else
            if ! eval "$cmd"; then
                print_message ERROR "$error_message: $cmd"
                return 1
            fi
        fi
    done

    print_message OK "$success_message"
}
# Function to install packages
# @description install_package_group is a function that installs packages for a given group
# @param $1 The name of the group to install packages for
# @note This function is used to install packages for a given group
install_package_group() {
    local group_name="$1"
    local packages="${PACKAGE_GROUPS[$group_name]}"
    
    if [ -n "$packages" ]; then
        print_message INFO "Installing $group_name packages: $packages"
        execute_process "Install $group_name packages" \
            --use-chroot \
            --error-message "Failed to install $group_name packages" \
            --success-message "$group_name packages installed successfully" \
            "pacman -S --noconfirm --needed $packages"
    else
        print_message WARNING "No packages defined for group: $group_name"
    fi
}
# Function to install all selected package groups
# @description install_selected_packages is a function that installs all selected package groups
# @note This function is used to install all selected package groups
install_selected_packages() {
    print_message INFO "Starting package installation"
    print_debug_info  # Add this line to print debug info
    for group in "${INSTALL_GROUPS[@]}"; do
        if [[ -v "PACKAGE_GROUPS[$group]" ]]; then
            print_message INFO "Installing group: $group"
            install_package_group "$group"
        else
            print_message WARNING "Skipping unknown package group: $group"
        fi
    done
    print_message OK "Package installation completed"
}

# @description print_debug_info is a function that prints debug information
# @note This function is used to print debug information
print_debug_info() {
    print_message DEBUG "Is PACKAGE_GROUPS an associative array? $(if [[ "$(declare -p PACKAGE_GROUPS 2>/dev/null)" =~ "declare -A" ]]; then echo "Yes"; else echo "No"; fi)"
    print_message DEBUG "Number of elements in PACKAGE_GROUPS: ${#PACKAGE_GROUPS[@]}"
    print_message DEBUG "Contents of PACKAGE_GROUPS:"
    for key in "${!PACKAGE_GROUPS[@]}"; do
        print_message DEBUG "  $key: ${PACKAGE_GROUPS[$key]}"
    done

    print_message DEBUG "Contents of INSTALL_GROUPS:"
    for group in "${INSTALL_GROUPS[@]}"; do
        print_message DEBUG "  $group"
    done
}
# @description install_arch_linux is the main installation function
# @note This function is used to install Arch Linux
install_arch_linux() {
    print_message INFO "Starting Arch Linux installation"

    # Initial setup
    # @description initial_setup is a function that performs initial setup
    # @note This function is used to perform initial setup
    execute_process "Initial setup" \
        --error-message "Initial setup failed" \
        --success-message "Initial setup completed" \
        "timedatectl set-ntp true" \
        "pacman -Sy archlinux-keyring --noconfirm" \
        "pacman -S --noconfirm --needed pacman-contrib terminus-font rsync reflector gptfdisk btrfs-progs glibc" \
        "setfont ter-v22b" \
        "sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf" \
        "pacman -Syy"

    # Mirror setup
    # @description mirror_setup is a function that sets up the mirror
    # @note This function is used to set up the mirror
    execute_process "Mirror setup" \
        --error-message "Mirror setup failed" \
        --success-message "Mirror setup completed" \
        "curl -4 'https://ifconfig.co/country-iso' > COUNTRY_ISO" \
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup"

    # Partitioning
    # @description partitioning is a function that partitions the device
    # @note This function is used to partition the device
    execute_process "Partitioning" \
        --error-message "Partitioning failed" \
        --success-message "Partitioning completed" \
        "if mountpoint -q /mnt; then umount -A --recursive /mnt; else echo '/mnt is not mounted'; fi" \
        "sgdisk -Z $DEVICE" \
        "sgdisk -n1:0:+1M -t1:ef02 -c1:'BIOSBOOT' $DEVICE" \
        "sgdisk -n2:0:+512M -t2:ef00 -c2:'EFIBOOT' $DEVICE" \
        "sgdisk -n3:0:0 -t3:8300 -c3:'ROOT' $DEVICE"

    # Formatting and mounting
    # @description formatting_and_mounting is a function that formats and mounts partitions
    # @note This function is used to format and mount partitions
    execute_process "Formatting and mounting" \
        --error-message "Formatting and mounting failed" \
        --success-message "Formatting and mounting completed" \
        "mkfs.vfat -F32 -n EFIBOOT $PARTITION_EFI" \
        "mkfs.btrfs -f -L ROOT $PARTITION_ROOT" \
        "mount -t btrfs $PARTITION_ROOT /mnt" \
        "btrfs subvolume create /mnt/@" \
        "btrfs subvolume create /mnt/@home" \
        "btrfs subvolume create /mnt/@var" \
        "btrfs subvolume create /mnt/@tmp" \
        "btrfs subvolume create /mnt/@.snapshots" \
        "umount /mnt" \
        "mount -o $MOUNT_OPTIONS,subvol=@ $PARTITION_ROOT /mnt" \
        "mkdir -p /mnt/{home,var,tmp,.snapshots,boot/efi}" \
        "mount -o $MOUNT_OPTIONS,subvol=@home $PARTITION_ROOT /mnt/home" \
        "mount -o $MOUNT_OPTIONS,subvol=@tmp $PARTITION_ROOT /mnt/tmp" \
        "mount -o $MOUNT_OPTIONS,subvol=@var $PARTITION_ROOT /mnt/var" \
        "mount -o $MOUNT_OPTIONS,subvol=@.snapshots $PARTITION_ROOT /mnt/.snapshots" \
        "mount -t vfat -L EFIBOOT /mnt/boot/efi"

    # Install base system
    # @description install_base_system is a function that installs base system
    # @note This function is used to install base system    
    execute_process "Installing base system" \
        --error-message "Base system installation failed" \
        --success-message "Base system installation completed" \
        "pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub ${MICROCODE}-ucode --noconfirm --needed"

    # Generate fstab
    # @description generate_fstab is a function that generates fstab
    # @note This function is used to generate fstab
    execute_process "Generating fstab" \
        --error-message "fstab generation failed" \
        --success-message "fstab generation completed" \
        "genfstab -U /mnt >> /mnt/etc/fstab"

    # Install GRUB
    # @description install_grub is a function that installs GRUB
    # @note This function is used to install GRUB   
    execute_process "Installing GRUB" \
        --use-chroot \
        --error-message "GRUB installation failed" \
        --success-message "GRUB installation completed" \
        "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB" \
        "grub-mkconfig -o /boot/grub/grub.cfg" 
    
    # Chroot operations
    # @description chroot_operations is a function that performs chroot operations
    # @note This function is used to perform chroot operations
    execute_process "Chroot operations" \
        --use-chroot \
        --error-message "Chroot operations failed" \
        --success-message "Chroot operations completed" \
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


    # Install additional packages
    # @description install_selected_packages is a function that installs selected packages
    # @note This function is used to install selected packages
    print_message DEBUG "PACKAGE_GROUPS before installation: ${!PACKAGE_GROUPS[*]}"
    install_selected_packages

    # Enable and start services
    # @description enable_and_start_services is a function that enables and starts services
    # @note This function is used to enable and start services
    execute_process "Enable and start services" \
        --use-chroot \
        --error-message "Enable and start services failed" \
        --success-message "Enable and start services completed" \
        "systemctl enable NetworkManager" \
        "systemctl enable sshd" \
        "systemctl enable cronie" \
        "systemctl enable bluetooth" \
        "systemctl enable ${DISPLAY_MANAGER}"

    # Enable and start services you can add more if you want dont foforget the \ (backslash)
    # last last has non and dont forget the "My command here" (double quotes)
    print_message OK "Arch Linux installation completed. You can now reboot into your new system."
}
# @description main is the main function that runs the installation process
# @note This function is used to run the installation process
main() {
    print_message INFO "Starting Arch Linux installation script"
    install_arch_linux
    print_message INFO "Installation process completed"
}
# @description main is the main function that runs the installation process
# @note This function is used to run the installation process
main "$@"
exit $?
