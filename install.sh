#!/bin/bash

# @description Arch Linux Installer
# This script is used to install Arch Linux on a device.
# It is designed to be run as root.
# Usage: bash install.sh
# Author: ssnow
# Date: 2024

# Determine the correct path to lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$SCRIPT_DIR/lib/lib.sh"

# Source the library functions
if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Initialize variables
ARCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ARCH_DIR
SCRIPTS_DIR="$ARCH_DIR/scripts"
STAGES_CONFIG="${STAGES_CONFIG:-$ARCH_DIR/stages.toml}"

# Set global debug mode (can be overridden by command line arguments)
export DEBUG_MODE=${DEBUG_MODE:-false}
# Ensure DRY_RUN is exported
export DRY_RUN="${DRY_RUN:-false}"
# Redirect stdout and stderr through log_process_output function
#exec > >($File_LOG) 2>&1

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) export DRY_RUN=true ;;
        --verbose) export VERBOSE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Main execution
main() {
    process_init "Main Installation Process"
    show_logo "Arch Linux Installer"
    print_message INFO "Welcome to the Arch Linux installer script"

    # Print message Set DRY_RUN to ?
    print_message PROC "DRY_RUN is set to: ${YELLOW}$DRY_RUN"
    print_message PROC "Print configuration: ${YELLOW}Info:"
    # Print system information
    print_system_info

    # Parse the stages TOML file
    parse_stages_toml "$STAGES_CONFIG" || print_message ERROR "Failed to parse stages.toml" exit 1

    # Create a sorted list of stages
    readarray -t SORTED_STAGES < <(printf '%s\n' "${!INSTALL_SCRIPTS[@]}" | sort)

    # Load configuration
    local vars=(format_type desktop_environment)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    # Print the INSTALL_SCRIPTS array for verification
    print_message INFO "Installation Stages and Scripts:"
    for stage in "${SORTED_STAGES[@]}"; do
        print_message INFO "  $stage: ${INSTALL_SCRIPTS[$stage]}"
    done

    run_install_scripts "$format_type" "$desktop_environment" || { print_message ERROR "Installation failed"; return 1; }

    print_message OK "Arch Linux installation completed successfully"
    process_end $?
}

# Run the main function
main "$@"
exit $?