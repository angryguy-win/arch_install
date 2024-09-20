#!/bin/bash

# @description Arch Linux Installer
# This script is used to install Arch Linux on a device.
# It is designed to be run as root for actual installation, but not for dry runs.
# Usage: bash install.sh [--dry-run] [--verbose]
# Author: ssnow
# Date: 2024

# Initialize variables with default values
export DEBUG_MODE=${DEBUG_MODE:-false}
export DRY_RUN=${DRY_RUN:-false}
export VERBOSE=${VERBOSE:-false}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) export DRY_RUN=true ;;
        --verbose) export VERBOSE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check for root privileges only if not in dry-run mode
if [[ "$DRY_RUN" != "true" && $EUID -ne 0 ]]; then
   echo "This script must be run as root for actual installation. Use --dry-run for testing without root." 
   exit 1
fi

# Set up important directories and files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ARCH_DIR="$SCRIPT_DIR"
export SCRIPTS_DIR="$ARCH_DIR/scripts"
 
export CONFIG_FILE="$ARCH_DIR/arch_config.cfg"

# Source the library functions
# shellcheck source=./lib/lib.sh
LIB_PATH="$SCRIPT_DIR/lib/lib.sh"
if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Main execution
main() {
    process_init "Main Installation Process"
    show_logo "Arch Linux Installer"
    print_message INFO "Welcome to the Arch Linux installer script"

    print_message PROC "DRY_RUN is set to: ${YELLOW}$DRY_RUN"
    #print_system_info

    export STAGES_CONFIG="${STAGES_CONFIG:-$ARCH_DIR/stages.toml}"

    # Parse the stages TOML file
    parse_stages_toml "$STAGES_CONFIG" || { print_message ERROR "Failed to parse stages.toml"; exit 1; }
    print_message DEBUG "Parsed stages.toml: ${STAGES_CONFIG}"

    # Debug: Print the contents of INSTALL_SCRIPTS
    print_message DEBUG "Contents of INSTALL_SCRIPTS:"
    for key in "${!INSTALL_SCRIPTS[@]}"; do
        print_message DEBUG "  Stage: $key"
        print_message DEBUG "    Scripts: ${INSTALL_SCRIPTS[$key]}"
    done

    # Load configuration
    load_config  || { print_message ERROR "Failed to load config"; exit 1; }

    print_message DEBUG "FORMAT_TYPE: $FORMAT_TYPE"
    print_message DEBUG "DESKTOP_ENVIRONMENT: $DESKTOP_ENVIRONMENT"

    # Run install scripts
    run_install_scripts "$FORMAT_TYPE" "$DESKTOP_ENVIRONMENT" "$DRY_RUN" || {
        print_message ERROR "Installation failed"
        exit 1
    }

    print_message OK "Arch Linux installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?