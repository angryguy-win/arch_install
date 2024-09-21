#!/bin/bash
# Generate Fstab Script
# Author: ssnow
# Date: 2024
# Description: Generate fstab script for Arch Linux installation

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


generate_fstab() {
    
    print_message INFO "Generating fstab"
    execute_process "Generating fstab" \
        --error-message "fstab generation failed" \
        --success-message "fstab generation completed" \
        "genfstab -U /mnt >> /mnt/etc/fstab"

}
grub_setup() {

    execute_process "Installing GRUB" \
        --use-chroot \
        --error-message "GRUB installation failed" \
        --success-message "GRUB installation completed" \
        "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB" \
        "grub-mkconfig -o /boot/grub/grub.cfg" 

}
main() {
    process_init "Generate Fstab"
    show_logo "Generate Fstab"
    print_message INFO "Starting generate fstab process"
    print_message INFO "DRY_RUN in $(basename "$0") is set to: ${YELLOW}$DRY_RUN"

    generate_fstab || { print_message ERROR "Generate fstab process failed"; return 1; }
    grub_setup || { print_message ERROR "GRUB setup process failed"; return 1; }
    print_message OK "Generate fstab process completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?