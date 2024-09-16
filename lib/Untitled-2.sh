#!/bin/bash

set -eo pipefail

# Configuration variables
COUNTRY_ISO="CA"
DEVICE="/dev/nvme0n1"
MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Toronto"
KEYMAP="us"
USERNAME="user"
PASSWORD="password"
HOSTNAME="hostname"

# Function to print messages
print_message() {
    local type=$1
    shift
    echo "[$type] $*"
}

# Function to execute commands with error handling
execute_command() {
    if ! "$@"; then
        print_message ERROR "Command failed: $*"
        exit 1
    fi
}
# Function to execute a command in chroot environment
execute_chroot_command() {
    local command="$1"
    local description="$2"

    print_message INFO "Executing: $description"
    if ! arch-chroot /mnt /bin/bash -c "$command"; then
        print_message ERROR "Failed: $description"
        return 1
    fi
    print_message OK "Completed: $description"
}

# Function to perform chroot operations
perform_chroot_operations() {
    print_message INFO "Starting chroot operations"

    local chroot_commands=(
        "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime::Set timezone"
        "hwclock --systohc::Sync hardware clock"
        "echo '$LOCALE UTF-8' > /etc/locale.gen::Set locale in locale.gen"
        "locale-gen::Generate locale"
        "echo 'LANG=$LOCALE' > /etc/locale.conf::Set LANG in locale.conf"
        "echo 'KEYMAP=$KEYMAP' > /etc/vconsole.conf::Set keymap"
        "echo '$HOSTNAME' > /etc/hostname::Set hostname"
        "echo 'root:$PASSWORD' | chpasswd::Set root password"
        "useradd -m -G wheel -s /bin/bash $USERNAME::Create user"
        "echo '$USERNAME:$PASSWORD' | chpasswd::Set user password"
        "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers::Configure sudo"
        "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB::Install GRUB"
        "grub-mkconfig -o /boot/grub/grub.cfg::Configure GRUB"
        "systemctl enable NetworkManager::Enable NetworkManager"
        "pacman -S --noconfirm networkmanager vim::Install additional packages"
    )

    for cmd in "${chroot_commands[@]}"; do
        IFS='::' read -r command description <<< "$cmd"
        if ! execute_chroot_command "$command" "$description"; then
            print_message ERROR "Chroot operations failed"
            return 1
        fi
    done

    print_message OK "Chroot operations completed successfully"
}
# Main installation function
install_arch_linux() {
    print_message INFO "Starting Arch Linux installation"

    # Initial setup
    print_message INFO "Initial setup"
    execute_command timedatectl set-ntp true
    execute_command pacman -Sy archlinux-keyring --noconfirm
    execute_command pacman -S --noconfirm --needed pacman-contrib terminus-font rsync reflector gptfdisk btrfs-progs

    # Mirror setup
    print_message INFO "Setting up mirrors"
    execute_command reflector -a 48 -c $COUNTRY_ISO -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

    # Partitioning
    print_message INFO "Partitioning"
    execute_command sgdisk -Z $DEVICE
    execute_command sgdisk -n1:0:+1M -t1:ef02 -c1:'BIOSBOOT' $DEVICE
    execute_command sgdisk -n2:0:+512M -t2:ef00 -c2:'EFIBOOT' $DEVICE
    execute_command sgdisk -n3:0:0 -t3:8300 -c3:'ROOT' $DEVICE

    # Formatting and mounting
    print_message INFO "Formatting and mounting"
    execute_command mkfs.vfat -F32 -n EFIBOOT ${DEVICE}p2
    execute_command mkfs.btrfs -f -L ROOT ${DEVICE}p3
    execute_command mount -t btrfs ${DEVICE}p3 /mnt

    # Create subvolumes
    print_message INFO "Creating subvolumes"
    execute_command btrfs subvolume create /mnt/@
    execute_command btrfs subvolume create /mnt/@home
    execute_command btrfs subvolume create /mnt/@var
    execute_command btrfs subvolume create /mnt/@tmp
    execute_command btrfs subvolume create /mnt/@.snapshots
    execute_command umount /mnt

    # Mount subvolumes
    print_message INFO "Mounting subvolumes"
    execute_command mount -o $MOUNT_OPTIONS,subvol=@ ${DEVICE}p3 /mnt
    execute_command mkdir -p /mnt/{home,var,tmp,.snapshots,boot/efi}
    execute_command mount -o $MOUNT_OPTIONS,subvol=@home ${DEVICE}p3 /mnt/home
    execute_command mount -o $MOUNT_OPTIONS,subvol=@tmp ${DEVICE}p3 /mnt/tmp
    execute_command mount -o $MOUNT_OPTIONS,subvol=@var ${DEVICE}p3 /mnt/var
    execute_command mount -o $MOUNT_OPTIONS,subvol=@.snapshots ${DEVICE}p3 /mnt/.snapshots
    execute_command mount -t vfat -L EFIBOOT /mnt/boot/efi

    # Install base system
    print_message INFO "Installing base system"
    execute_command pacstrap /mnt base base-devel linux linux-firmware efibootmgr grub

    # Generate fstab
    print_message INFO "Generating fstab"
    execute_command genfstab -U /mnt >> /mnt/etc/fstab

    # Chroot operations
    print_message INFO "Performing chroot operations"
    # Perform chroot operations
    perform_chroot_operations || {
        print_message ERROR "Installation failed during chroot operations"
        exit 1
    }

    print_message OK "Arch Linux installation completed. You can now reboot into your new system."
}

# Main execution
main() {
    print_message INFO "Starting Arch Linux installation script"
    install_arch_linux
    print_message INFO "Installation process completed"
}

# Run the main function
main "$@"
exit $?