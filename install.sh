#!/bin/env bash

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
while [ "$#" -gt 0 ]; do
    case $1 in
        -d|--dry-run) export DRY_RUN=true ;;
        -v|--verbose) export VERBOSE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Set up important directories and files
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
export ARCH_DIR="$SCRIPT_DIR"
export SCRIPTS_DIR="$ARCH_DIR/scripts"
export CONFIG_FILE="$ARCH_DIR/arch_config.cfg"

# Source the library functions
LIB_PATH="$SCRIPT_DIR/lib/lib.sh"
#shellcheck source=../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$SCRIPT_DIR/lib/lib.sh"  
else
    print_message ERROR "Library file not found: $LIB_PATH"
    exit 1
fi

init_log_file true "$ARCH_DIR/process.log"
if [ -f "$ARCH_DIR/process.log" ]; then
    touch "$ARCH_DIR/process.log"
fi

# Main execution
main() {
    MAIN_START_TIMESTAMP=""
    MAIN_END_TIMESTAMP=""
    MAIN_INSTALLATION_TIME=""
    MAIN_START_TIMESTAMP=$(date -u +"%F %T")
    print_message DEBUG "============ Starting Main Installation Process ============="
    process_init "Main Installation Process"
    print_message INFO "Welcome to the Arch Linux installer script"
    print_message PROC "DRY_RUN is set to: ${YELLOW}$DRY_RUN"
    print_message DEBUG "From the install.sh file in the: $SCRIPT_DIR"
    print_message DEBUG "Lib.sh file in the: $SCRIPT_DIR/lib/lib.sh"
    print_message DEBUG "ARCH_DIR: $ARCH_DIR"
    print_message DEBUG "SCRIPTS_DIR: $SCRIPTS_DIR"
    print_message DEBUG "CONFIG_FILE: $CONFIG_FILE" 
    #print_system_info

    export STAGES_CONFIG="${STAGES_CONFIG:-$ARCH_DIR/stages.toml}"

    # Reads config file arch_config.toml and copies it to arch_config.cfg
    read_config || { print_message ERROR "Failed to read config"; exit 1; }
    # Load configuration
    load_config  || { print_message ERROR "Failed to load config"; exit 1; }
    print_message DEBUG "FORMAT_TYPE: $FORMAT_TYPE"
    print_message DEBUG "DESKTOP_ENVIRONMENT: $DESKTOP_ENVIRONMENT"

    if ! check_required_scripts; then
        print_message ERROR "Missing required scripts. Aborting installation."
        exit 1
    fi

    # If we reach this point, all required scripts are present
    print_message OK "All required scripts are present."

    # Run install scripts
    process_installation_stages "$FORMAT_TYPE" "$DESKTOP_ENVIRONMENT" || {
        print_message ERROR "Installation failed"
        exit 1
    }

    print_message OK "Arch Linux installation completed successfully"
    MAIN_END_TIMESTAMP=$(date -u +"%F %T")
    MAIN_INSTALLATION_TIME=$(date -u -d @$(($(date -d "$MAIN_END_TIMESTAMP" '+%s') - $(date -d "$MAIN_START_TIMESTAMP" '+%s'))) '+%T')
    printf "%b\n" "Installation start ${WHITE}$MAIN_START_TIMESTAMP${NC}, end ${WHITE}$MAIN_END_TIMESTAMP${NC}, time ${WHITE}$MAIN_INSTALLATION_TIME${NC}"
    process_end $?
}

# Run the main function
main "$@"
exit $?