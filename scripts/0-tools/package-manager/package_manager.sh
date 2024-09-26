#!/bin/bash
# @description Package manager
# @version $SCRIPT_VERSION
# @author ssnw
# @date 2024-07-29
# @license MIT

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$SCRIPT_DIR/lib_tools.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib_tools.sh at $LIB_PATH" >&2
    exit 1
fi
# Set default values
VERBOSE=${VERBOSE:-false}
DRY_RUN=${DRY_RUN:-false}
LOG_FILE=${LOG_FILE:-"$SCRIPT_DIR/package_manager.log"}
export VERBOSE="$VERBOSE"

initialize_variables() {
    EXCLUDE_PACKAGES=()
    REMOVE_PACKAGES=()
    INSTALL_PACKAGES=()
    UNINSTALL_PACKAGES=()
    PROCESSED_PACKAGES=()
    SKIPPED_PACKAGES=()
    FAILED_PACKAGES=()
    GENERATE_LIST=false
    PACKAGE_LIST_FILE="$SCRIPT_DIR/package_config.toml"
    #PACKAGE_LIST_FILE="$SCRIPT_DIR/package_list.toml"
    DEFAULT_LOG_FILE="$SCRIPT_DIR/package_manager.log"
    LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
    SCRIPT_VERSION="2.0.0"
    START_TIME=$(date +%s)
    END_TIME=0
    EXECUTION_TIME=0

    VERBOSE=false
    DRY_RUN=false
    UNINSTALL=false
    INSTALL_FLAG=false
    #SKIP_INSTALLED=false
    AUR_PACKAGE_MANAGER=${AUR_PACKAGE_MANAGER:-paru}

    FORCE_UPDATE=false
    PARALLEL_JOBS=4
    SELECTED_PACKAGES=()
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dry-run) DRY_RUN=true ;;
            -v|--verbose) VERBOSE=true ;;
            -e|--exclude) IFS=',' read -ra EXCLUDE_PACKAGES <<< "$2"; shift ;;
            -r|--remove) 
                if [[ -f "$2" ]]; then
                    mapfile -t REMOVE_PACKAGES < "$2"
                else
                    IFS=',' read -ra REMOVE_PACKAGES <<< "$2"
                fi
                shift 
                ;;
            -u|--uninstall)
                UNINSTALL=true
                if [[ -n "$2" && "$2" != -* ]]; then
                    if [[ -f "$2" ]]; then
                        UNINSTALL_MODE="file"
                        PACKAGE_LIST_FILE="$2"
                    else
                        UNINSTALL_MODE="packages"
                        IFS=',' read -ra UNINSTALL_PACKAGES <<< "$2"
                    fi
                    shift
                else
                    UNINSTALL_MODE="file"
                fi
                ;;
            -g|--generate) 
                GENERATE_LIST=true 
                ;;
            -o|--output) 
                PACKAGE_LIST_FILE="$2"
                shift
                ;;
            -l|--log-file)
                if [[ -n "$2" && "$2" != -* ]]; then
                    LOG_FILE="$2"
                    shift
                else
                    LOG_FILE="$DEFAULT_LOG_FILE"
                fi
                ;;
            -h|--help) show_help; exit 0 ;;
            -i|--install)
                INSTALL_FLAG=true
                if [[ -n "$2" && "$2" != -* ]]; then
                    if [[ -f "$2" ]]; then
                        INSTALL_MODE="file"
                        PACKAGE_LIST_FILE="$2"
                    elif [[ "$2" == *","* ]]; then
                        INSTALL_MODE="list"
                        IFS=',' read -ra INSTALL_PACKAGES <<< "$2"
                    else
                        INSTALL_MODE="single"
                        INSTALL_PACKAGES=("$2")
                    fi
                    shift
                else
                    INSTALL_MODE="full"
                fi
                ;;
            -f|--force-update) FORCE_UPDATE=true ;;
            -j|--jobs) 
                PARALLEL_JOBS="$2"
                shift
                ;;
            -s|--select)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    SELECTED_PACKAGES+=("$1")
                    shift
                done
                ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
        shift
    done
}
perform_main_operations() {
    local start_time=$(date +%s)

    if [[ ${#REMOVE_PACKAGES[@]} -gt 0 ]]; then
        print_message "INFO" "Removing packages..."
        remove_packages OFFICIAL_PACKAGES
        remove_packages AUR_PACKAGES
        remove_packages PACKAGE_GROUPS
    fi

    if [[ "$UNINSTALL" == "true" ]]; then
        if [[ ${#UNINSTALL_PACKAGES[@]} -gt 0 ]]; then
            print_message "INFO" "Uninstalling packages..."
            uninstall_packages "${UNINSTALL_PACKAGES[@]}"
        else
            print_message "WARNING" "No packages specified for uninstallation"
        fi
    fi

    if [[ "$INSTALL_FLAG" == "true" ]]; then
        handle_installation
    else
        print_message "INFO" "No installation flag provided. Skipping package installation."
    fi

    # Log resource usage every 5 minutes during long operations
    local current_time=$(date +%s)
    if (( current_time - start_time >= 300 )); then
        log_resource_usage
        start_time=$current_time
    fi
}
main() {
    verbose_print "DEBUG: Starting main function"
    initialize_variables
    #verbose_print "DEBUG: Variables initialized"
    parse_args "$@"
    #verbose_print "DEBUG: Arguments parsed"
    #echo "DEBUG: VERBOSE=$VERBOSE"
    #verbose_print "DEBUG: setup_error_handling"
    setup_error_handling
    #verbose_print "DEBUG: setup_error_handling completed"
    setup_logging
    get_system_info
    update_package_list

    print_message "INFO" "Starting package manager... ($(date +%Y-%m-%d\ %H:%M:%S))"
    print_message "INFO" "Script version: ${SCRIPT_VERSION}"
    print_message "INFO" "Using package list file: ${PACKAGE_LIST_FILE}"

    # Log initial resource usage
    log_resource_usage

    # Set the operation based on command-line arguments
    if [ "$INSTALL_FLAG" = "true" ]; then
        OPERATION="install"
    elif [ "$UNINSTALL" = "true" ]; then
        OPERATION="uninstall"
    else
        print_message "ERROR" "No operation specified. Use -i for install or -u for uninstall."
        exit 1
    fi

    # Perform main operations
    if [ "$OPERATION" = "install" ]; then
        handle_installation
        print_operation_summary "installation" "installed"
    elif [ "$OPERATION" = "uninstall" ]; then
        handle_uninstallation
        print_operation_summary "uninstallation" "uninstalled"
    fi

    # Log final resource usage
    log_resource_usage

    END_TIME=$(date +%s)
    EXECUTION_TIME=$((END_TIME - START_TIME))
    print_message "INFO" "Total execution time: ${EXECUTION_TIME} seconds"
}

main "$@"

export VERBOSE
export FORCE_UPDATE
export SELECTED_PACKAGES
export -f is_package_installed
export -f verbose_print
export -f print_message
export -f log 
export COLORS
export LOG_FILE
export DRY_RUN
export AUR_PACKAGE_MANAGER
export SKIP_INSTALLED
export PROCESSED_PACKAGES
export SKIPPED_PACKAGES
export FAILED_PACKAGES
export -f check_for_updates
export -f confirm_installation
export -f check_package_updates
exit 0