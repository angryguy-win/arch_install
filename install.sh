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
while [ "$#" -gt 0 ]; do
    case $1 in
        -d|--dry-run) export DRY_RUN=true ;;
        -v|--verbose) export VERBOSE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Set up important directories and files
## SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
## SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # Changed from "${BASH_SOURCE[0]}" to "$0"
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
set -o errtrace
set -o functrace
set_error_trap

# Initialize log file
init_log_file true "$ARCH_DIR/process.log"
if [ -f "$ARCH_DIR/process.log" ]; then
    touch "$ARCH_DIR/process.log"
fi
# Ensure stages array is available
if [ -z "${stages[*]}" ]; then
    print_message ERROR "Stages array is empty or not defined in lib.sh"
    exit 1
fi
# @description Resume installation from checkpoint
# @arg $1 string Format type
# @arg $2 string Desktop environment
resume_installation() {
    local format_type="$1"
    local desktop_environment="$2"

    print_message INFO "Resuming from checkpoint:"
    print_message INFO "  Stage: $CURRENT_STAGE"
    print_message INFO "  Script: $CURRENT_SCRIPT"
    print_message INFO "  Function: $CURRENT_FUNCTION"

    local resume_started=false

    # Sort the stages array keys to ensure correct order
    readarray -t sorted_stages < <(for key in "${!stages[@]}"; do echo "$key"; done | sort)

    for stage in "${sorted_stages[@]}"; do
        if [[ "$resume_started" == false ]]; then
            if [[ "$stage" == "$CURRENT_STAGE" ]]; then
                resume_started=true
            else
                continue
            fi
        fi

        IFS=' ' read -ra scripts <<< "${stages[$stage]}"
        local script_resume_started=false

        for script_info in "${scripts[@]}"; do
            IFS=':' read -r script type <<< "$script_info"

            # Replace placeholder with actual desktop environment
            script=${script//\{desktop_environment\}/$desktop_environment}

            if [[ "$resume_started" == true && "$script_resume_started" == false ]]; then
                if [[ "$script" == "$CURRENT_SCRIPT" ]]; then
                    script_resume_started=true
                else
                    continue
                fi
            fi

            if [[ "$resume_started" == true && "$script_resume_started" == true ]]; then
                execute_script "$stage" "$script" "$type" "$format_type" "$desktop_environment" "$CURRENT_FUNCTION"
                CURRENT_FUNCTION=""
            fi
        done
        CURRENT_SCRIPT=""
    done
}
# @description Execute script
# @arg $1 string Stage
# @arg $2 string Script
# @arg $3 string Type
# @arg $4 string Format type
# @arg $5 string Desktop environment
# @arg $6 string Resume function    
execute_script() {
    local stage="$1"
    local script="$2"
    local type="$3"
    local format_type="$4"
    local desktop_environment="$5"
    local resume_function="$6"

    script=${script//\{desktop_environment\}/$desktop_environment}
    script_path="${SCRIPTS_DIR}/${stage}/${script}"

    if [[ ! -f "$script_path" ]]; then
        print_message WARNING "Script not found: $script_path"
        return 0
    fi

    if [[ -n "$resume_function" ]]; then
        print_message INFO "Resuming from function $resume_function in $script"
        bash "$script_path" --resume-function "$resume_function"
    else
        bash "$script_path"
    fi

    # Update checkpoint after script execution
    save_checkpoint "$stage" "$script" ""

    if [[ $? -eq 0 ]]; then
        print_message ACTION "Successfully executed: $script_path"
    else
        if [[ "$type" == "m" ]]; then
            print_message ERROR "Mandatory script failed: $script in stage $stage"
            return 1
        else
            print_message WARNING "Optional script failed: $script in stage $stage"
        fi
    fi
}
# @description Start fresh installation
# @arg $1 string Format type
# @arg $2 string Desktop environment
start_fresh_installation() {
    local format_type="$1"
    local desktop_environment="$2"

    rm -f "$CHECKPOINT_FILE"  # Ensure no old checkpoint exists
    process_installation_stages "$format_type" "$desktop_environment"
}
# @description Main installation
# @arg $1 string Format type
# @arg $2 string Desktop environment
main_installation() {
    local format_type="$1"
    local desktop_environment="$2"

    if resume_from_checkpoint; then
        print_message INFO "Checkpoint found. Resuming installation."
        read -p "Do you want to resume from the last checkpoint? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            resume_installation "$format_type" "$desktop_environment"
        else
            print_message INFO "Starting fresh installation"
            rm -f "$CHECKPOINT_FILE"
            start_fresh_installation "$format_type" "$desktop_environment"
        fi
    else
        print_message INFO "No checkpoint found. Starting fresh installation."
        start_fresh_installation "$format_type" "$desktop_environment"
    fi
}
# Main execution
main() {
    MAIN_START_TIMESTAMP=""
    MAIN_END_TIMESTAMP=""
    MAIN_INSTALLATION_TIME=""

    MAIN_START_TIMESTAMP=$(date -u +"%F %T")
    print_message DEBUG "======================= Starting Main Installation Process ======================="
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

    # Parse the stages TOML file
    #parse_stages_toml "$STAGES_CONFIG" || { print_message ERROR "Failed to parse stages.toml"; exit 1; }
    #print_message DEBUG "Parsed stages.toml: ${STAGES_CONFIG}"

    # Debug: Print the contents of INSTALL_SCRIPTS
    #print_message DEBUG "Contents of INSTALL_SCRIPTS:"
    #for key in "${!INSTALL_SCRIPTS[@]}"; do
    #    print_message DEBUG "  $key: ${INSTALL_SCRIPTS[$key]}"
    #done
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
        main_installation "$FORMAT_TYPE" "$DESKTOP_ENVIRONMENT" || {
        print_message ERROR "Installation failed"
        exit 1
    }
    # Run install scripts
    #process_installation_stages "$FORMAT_TYPE" "$DESKTOP_ENVIRONMENT" || {
    #    print_message ERROR "Installation failed"
    #    exit 1
    #}

    print_message OK "Arch Linux installation completed successfully"
    MAIN_END_TIMESTAMP=$(date -u +"%F %T")
    MAIN_INSTALLATION_TIME=$(date -u -d @$(($(date -d "$MAIN_END_TIMESTAMP" '+%s') - $(date -d "$MAIN_START_TIMESTAMP" '+%s'))) '+%T')
    printf "%b\n" "Installation start ${WHITE}$MAIN_START_TIMESTAMP${NC}, end ${WHITE}$MAIN_END_TIMESTAMP${NC}, time ${WHITE}$MAIN_INSTALLATION_TIME${NC}"
    process_end $?
}

# Run the main function
main "$@"
exit $?
