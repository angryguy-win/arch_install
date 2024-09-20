#!/bin/bash
# Lib.sh file
# Location: /lib/lib.sh
# Author: ssnow
# Date: 2024
# Description: This file contains all the functions used in the install script
#              and other scripts.

set -eo pipefail

# Use the values set in install.sh, or use defaults if not set
DRY_RUN="${DRY_RUN:-false}"
DEBUG_MODE="${DEBUG_MODE:-false}"
VERBOSE="${VERBOSE:-false}"

# Color codes
export TERM=xterm-256color
declare -A COLORS
COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [MAGENTA]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [ORANGE]='\033[0;33m'
    [PURPLE]='\033[0;35m'
    [L_PURPLE]='\033[1;35m'
    [D_GRAY]='\033[1;30m'
    [L_GRAY]='\033[0;37m'
    [L_RED]='\033[1;31m'
    [L_GREEN]='\033[1;32m'
    [L_YELLOW]='\033[1;33m'
    [L_BLUE]='\033[1;34m'
    [L_MAGENTA]='\033[1;35m'
    [L_CYAN]='\033[1;36m'
    [I_RED]='\033[0;91m'
    [I_GREEN]='\033[0;92m'
    [I_YELLOW]='\033[0;93m'
    [I_BLUE]='\033[0;94m'
    [I_MAGENTA]='\033[0;95m'
    [I_CYAN]='\033[0;96m'
    [I_GRAY]='\033[0;90m'
    [WHITE]='\033[1;37m'
    [RESET]='\033[0m'
)
export COLORS

# Global variables (use values from install.sh if set, otherwise use defaults)
# @note the blank variables are used for the user spesific variables.
# @note if the blank variables are not set by the load_config function, the script can not proceed.
# @note all the other variable the defaults can be used
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"
FORMAT_TYPE="${FORMAT_TYPE:-btrfs}"
DESKTOP_ENVIRONMENT="${DESKTOP_ENVIRONMENT:-none}"
COUNTRY_ISO="${COUNTRY_ISO:-US}"
DEVICE=""
PARTITION_BIOSBOOT=""
PARTITION_EFI=""
PARTITION_ROOT=""
PARTITION_HOME=""
PARTITION_SWAP=""
MOUNT_OPTIONS="${MOUNT_OPTIONS:-noatime,compress=zstd,ssd,commit=120}"
LOCALE="${LOCALE:-en_US.UTF-8}"
TIMEZONE="${TIMEZONE:-UTC}"
KEYMAP="${KEYMAP:-us}"
USERNAME="${USERNAME:-user}"
PASSWORD="${PASSWORD:-changeme}"
HOSTNAME="${HOSTNAME:-arch}"
MICROCODE=""
GPU_DRIVER=""
TERMINAL="${TERMINAL:-alacritty}"
SUBVOLUME="${SUBVOLUME:-@,@home,@var,@.snapshots}"
LUKS="${LUKS:-false}"
LUKS_PASSWORD="${LUKS_PASSWORD:-changeme}"
SHELL="${SHELL:-bash}"
DESKTOP_ENVIRONMENT="${DESKTOP_ENVIRONMENT:-none}"


# Script-related variables
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="1.0.0"

# Log file setup
LOG_DIR="/tmp/arch-install-logs"
LOG_FILE="$LOG_DIR/arch_install.log"
PROCESS_LOG="$LOG_DIR/process.log"

# Create log directory and files if they don't exist
mkdir -p "$LOG_DIR" || { echo "Failed to create log directory: $LOG_DIR"; exit 1; }
touch "$LOG_FILE" "$PROCESS_LOG" || { echo "Failed to create log files"; exit 1; }

# Debug information
if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "DEBUG: DRY_RUN is set to $DRY_RUN"
    echo "DEBUG: VERBOSE is set to $VERBOSE"
    echo "DEBUG: DEBUG_MODE is set to $DEBUG_MODE"
    echo "DEBUG: LOG_DIR is set to $LOG_DIR"
    echo "DEBUG: CONFIG_FILE is set to $CONFIG_FILE"
fi

# Error handling
trap 'log "ERROR" "An error occurred. Exiting."; exit 1' ERR

# @description Displays Arch logo
# @noargs
show_logo () {
    # This will display the Logo banner and a message
    local logo_message=$1
    local border=${COLORS[BLUE]}
    local text_color=${COLORS[GREEN]}
    local logo_message_color=${COLORS[GREEN]}
echo -ne " 
${border}-------------------------------------------------------------------------
${logo_message_color}
                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
${border}------------------------------------------------------------------------
                ${text_color} $logo_message
${border}------------------------------------------------------------------------
${RESET}\n"
}
# @description Logging function
# @arg $1 string Level.
# @arg $2 string Message.
# @arg $3 string Highlight (optional).
log() {
    local level=${1:-INFO}
    shift
    local message=${*}
    local timestamp
    local prefix="[$type]"
    local log_entry
    local stripped_entry

    # Set the Variables
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Construct the log message without color codes
    local log_entry="${timestamp} ${prefix} ${message}"
    ensure_log_directory || return
    # No need for a separate stripped_entry variable
    if ! echo "$log_entry" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" >> "$LOG_FILE"; then
        #echo "$log_entry" >> "$PROCESS_LOG" 
        print_message ERROR "Failed to write to log file: $LOG_FILE"
        return 1
    fi
    # TODO: Implement log rotation to manage log file size
}
export -f log
# @description Print formatted messages
# @param type Message type
# @param message Message to print
print_message() {
    local type="${1:-INFO}"
    shift
    local message="${*}"
    local prefix_color=""
    local prefix="[$type]"
    local color="${COLORS[$type]:-${COLORS[WHITE]}}"
    local reset="${COLORS[RESET]}"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"


    if [[ -n "${COLORS[*]:-}" ]]; then
        case "$type" in
            INFO) prefix_color="${COLORS[BLUE]:-}"; prefix=" [INFO]" ;;
            SUCCESS) prefix_color="${COLORS[GREEN]:-}"; prefix="[SUCCESS]" ;;
            WARNING) prefix_color="${COLORS[YELLOW]:-}"; prefix=" [WARNING]" ;;
            ERROR) prefix_color="${COLORS[RED]:-}"; prefix=" [ERROR]" ;;
            ACTION) prefix_color="${COLORS[MAGENTA]:-}"; prefix=" [ACTION]" ;;
            PROC) prefix_color="${COLORS[CYAN]:-}"; prefix=" [PROC]" ;;
            DRY-RUN) prefix_color="${COLORS[YELLOW]:-}"; prefix=" [DRY-RUN]" ;;
            V) prefix_color="${COLORS[MAGENTA]:-}"; prefix=" [V]" ;;
            *) prefix_color="${COLORS[WHITE]:-}"; prefix="  [${type^^}]" ;;
        esac
    fi

    if [[ "$VERBOSE" != true && "$type" == "DEBUG" ]]; then
        return  # Suppress DEBUG messages if VERBOSE is not true
    fi

    # Compose the message
    local formatted_message="${prefix_color}${prefix} ${COLORS[RESET]:-} ${message}"
    printf "%b %s\n" "$formatted_message"
    #printf "%b%s%b %s\n" "$prefix_color" "$prefix" "${COLORS[RESET]:-}" "$message"

    # Append to log file
    if [[ -n "${LOG_FILE:-}" ]]; then
        log "$type" "$message"
    fi

}
export -f print_message
export COLORS
export LOG_FILE
# @description Function to print verbose messages
# @param message Message to print
verbose_print() {
    local message="$1"
    if [[ "${VERBOSE:-false}" = true ]]; then
        print_message V "$message"
    fi
}
export -f verbose_print
# @description Print debug information
# @noargs
print_system_info() {
    # Define variables
    local INSTALL_SCRIPT
    local ARCH_CONFIG_TOML
    local ARCH_CONFIG_CFG
    local LOG_FILE
    local PROCESS_LOG
    local DEBUG_LOG
    local ERROR_LOG
    local SCRIPT_DIR
    local total_ram_kb
    local RAM_AMOUNT
    local CPU_MODEL
    local CPU_CORES
    local CPU_THREADS
    local DISK_SIZE
    local DISK_SIZE_GB
    local GPU_VENDOR
    local GPU_MODEL
    local GPU_RAM
    local GPU_RAM_GB

    # Set the variables 
    INSTALL_SCRIPT="$ARCH_DIR/install.sh"
    ARCH_CONFIG_TOML="$ARCH_DIR/arch_config.toml"
    ARCH_CONFIG_CFG="$ARCH_DIR/arch_config.cfg"
    LOG_FILE="$LOG_DIR/arch_install.log"
    PROCESS_LOG="$LOG_DIR/process.log"
    DEBUG_LOG="$LOG_DIR/debug.log"
    ERROR_LOG="$LOG_DIR/error.log"
    SCRIPT_DIR="$ARCH_DIR"

    print_message INFO "--- System Information ---"

    # RAM
    print_message INFO "Getting RAM information"
    ram || { print_message ERROR "Failed to get RAM information"; return 1; }

    # CPU
    print_message INFO "Getting CPU information"
    cpu || { print_message ERROR "Failed to get CPU information"; return 1; }

    # Disk
    print_message INFO "The drive list"
    drive_list || { print_message ERROR "Failed to get drive list"; return 1; }

    # GPU
    print_message INFO "Getting GPU information"
    gpu_type || { print_message ERROR "Failed to get GPU information"; return 1; }

    print_message INFO "--- Debug Information ---"
    print_message INFO "SCRIPT_NAME: " "${SCRIPT_NAME:-Unknown}"
    print_message INFO "Current working directory: " "$(pwd)"
    print_message INFO "Install Script: " "${INSTALL_SCRIPT:-Unknown} ($(file_exists "${INSTALL_SCRIPT:-}"))"
    print_message INFO "arch_config.toml: " "${ARCH_CONFIG_TOML:-Unknown} ($(file_exists "${ARCH_CONFIG_TOML:-}"))"
    print_message INFO "arch_config.cfg: " "${ARCH_CONFIG_CFG:-Unknown} ($(file_exists "${ARCH_CONFIG_CFG:-}"))"
    print_message INFO "ARCH_DIR: " "${ARCH_DIR:-Unknown} ($(file_exists "${ARCH_DIR:-}"))"
    print_message INFO "SCRIPT_DIR: " "${SCRIPT_DIR:-Unknown} ($(file_exists "${SCRIPT_DIR:-}"))"
    print_message INFO "CONFIG_FILE: " "${CONFIG_FILE:-Unknown} ($(file_exists "${CONFIG_FILE:-}"))"
    print_message INFO "SCRIPT_VERSION: " "${SCRIPT_VERSION:-Unknown}"
    print_message INFO "DRY_RUN: " "${DRY_RUN:-false}"
    print_message INFO "Bash version: " "${BASH_VERSION}"
    print_message INFO "User running the script: " "$(whoami)"

    print_message INFO "--------- Logs -----------"
    print_message INFO "LOG_DIR: " "${LOG_DIR:-Unknown} ($(file_exists "${LOG_DIR:-}"))"
    print_message INFO "LOG_FILE: " "${LOG_FILE:-Unknown} ($(file_exists "${LOG_FILE:-}"))"
    print_message INFO "PROCESS_LOG: " "${PROCESS_LOG:-Unknown} ($(file_exists "${PROCESS_LOG:-}"))"

    print_message INFO "---Install config files---"
    for config_file in "${ARCH_CONFIG_TOML:-}" "${ARCH_CONFIG_CFG:-}"; do
        if [[ -f "$config_file" ]]; then
            print_message INFO "Contents of ${YELLOW}$(basename "$config_file"):"
            while IFS= read -r line; do
                print_message INFO "    $line"
            done < "$config_file"
        fi
    done
    print_message INFO "------------------------"
}
ram() {
    if total_ram_kb=$(free | awk '/Mem:/ {print $2}'); then
        RAM_AMOUNT=$(awk "BEGIN {printf \"%.1f\", $total_ram_kb / 1048576}")
        print_message INFO "RAM: " "$RAM_AMOUNT GB"
        set_option "RAM_AMOUNT" "$RAM_AMOUNT" || { print_message ERROR "Failed to set RAM_AMOUNT"; return 1; }
    else
        print_message WARNING "Unable to determine RAM amount"
    fi
}
# @description Get CPU information
# @noargs   
cpu() {
    if CPU_MODEL=$(lscpu | awk -F': +' '/Model name/ {print $2}'); then
        print_message INFO "CPU Model: " "$CPU_MODEL"
        set_option "CPU_MODEL" "$CPU_MODEL" || { print_message ERROR "Failed to set CPU_MODEL"; return 1; }
    else
        print_message WARNING "Unable to determine CPU model"
    fi

    if CPU_CORES=$(nproc 2>/dev/null); then
        print_message INFO "CPU Cores: " "$CPU_CORES"
        set_option "CPU_CORES" "$CPU_CORES" || { print_message ERROR "Failed to set CPU_CORES"; return 1; }
    else
        print_message WARNING "Unable to determine CPU core count"
    fi

    if CPU_THREADS=$(lscpu | awk '/^CPU\(s\):/ {print $2}'); then
        print_message INFO "CPU Threads: " "$CPU_THREADS"
        set_option "CPU_THREADS" "$CPU_THREADS" || { print_message ERROR "Failed to set CPU_THREADS"; return 1; }
    else
        print_message WARNING "Unable to determine CPU thread count"
    fi
}
gpu_type() {
    local gpu_type=$(lspci | grep -E "VGA|3D|Display")
    set_option "GPU_TYPE" "$gpu_type" || { print_message ERROR "Failed to set GPU_TYPE"; return 1; }
    print_message INFO "GPU Type: " "$gpu_type"

}
# @description Get GPU information
# @noargs
gpu() {
    if command -v lspci >/dev/null 2>&1; then
        # Get the relevant GPU lines
        GPU_INFO=$(lspci | grep -E "VGA compatible controller|Audio device" | grep -i "AMD/ATI")

        if [[ -n "$GPU_INFO" ]]; then
            # Loop through each line of GPU information
            while IFS= read -r line; do
                # Extract GPU Location
                GPU_LOCATION=$(echo "$line" | cut -d' ' -f1-3)  # Get the first three fields (including the colon)

                # Extract GPU Details
                GPU_DETAILS=$(echo "$line" | cut -d':' -f2- | sed 's/^[ \t]*//')  # Get everything after the first colon and trim leading spaces

                # Remove any unwanted prefixes from GPU Details
                GPU_DETAILS=$(echo "$GPU_DETAILS" | sed 's/^[0-9]*\.[0-9]* //')  # Remove leading "00.0" or "00.1"

                # Print formatted output
                print_message INFO "GPU Location:  " "${GPU_LOCATION}"
                print_message INFO "GPU Details:   " "${GPU_DETAILS}"
            done <<< "$GPU_INFO"
        else
            print_message WARNING "No AMD/ATI GPU information found in lspci output"
        fi
    else
        print_message WARNING "lspci not available"
    fi

    # Function to check command availability
    if command -v lspci >/dev/null 2>&1; then
        if GPU_INFO=$(lspci -v | grep -A 10 -i "VGA\|Display\|3D" 2>/dev/null); then
            # Extract the full GPU line
            GPU_LINE=$(echo "$GPU_INFO" | head -n1)

            # Split the GPU information at the desired point
            GPU_PART1=$(echo "$GPU_LINE" | cut -d'[' -f1 | sed 's/ $//')
            GPU_PART2=$(echo "$GPU_LINE" | sed -n 's/.*\(\[AMD.*\)/\1/p')

            # Format and print the information
            print_message INFO "GPU Part 1: " "${GPU_PART1}"
            print_message INFO "GPU Part 2: " "${GPU_PART2}"

            # Additional information (if needed)
            GPU_MEMORY=$(echo "$GPU_INFO" | grep -i "Memory at" | head -1 | awk '{print $5}')
            if [[ -n "$GPU_MEMORY" ]]; then
                print_message INFO "GPU Memory: " "${GPU_MEMORY}"
            fi
        else
            print_message WARNING "No GPU information found in lspci output"
        fi
    else
        print_message WARNING "lspci not available"
    fi

    # Try glxinfo
    if command -v glxinfo >/dev/null 2>&1; then
        print_message DEBUG "Attempting to use glxinfo"
        if GPU_INFO=$(glxinfo 2>&1 | grep "OpenGL renderer"); then
            print_message INFO "GPU (from glxinfo): " "$GPU_INFO"
        else
            print_message WARNING "glxinfo failed or no OpenGL renderer found"
        fi
    else
        print_message WARNING "glxinfo not available"
    fi

    # Try reading from /sys
    if [[ -d /sys/class/graphics/fb0 ]]; then
        print_message DEBUG "Attempting to read from /sys/class/graphics/fb0"
        if [[ -f /sys/class/graphics/fb0/name ]]; then
            GPU_NAME=$(cat /sys/class/graphics/fb0/name)
            print_message INFO "GPU (from /sys): " "$GPU_NAME"
        else
            print_message WARNING "Unable to read GPU name from /sys"
        fi
    else
        print_message WARNING "/sys/class/graphics/fb0 not available"
    fi

    # If all methods fail
    if [[ -z "$GPU_LINE" && -z "$GPU_INFO" && -z "$GPU_NAME" ]]; then
        print_message ERROR "Unable to determine GPU information using any method"
    fi
}
# @description Check if a file exists
# This function checks if a file exists
# Helper function for print_debug_info
# @arg $1 string File path.
file_exists() {
    if [ -e "$1" ]; then
        printf "${COLORS[GREEN]}%s %s${RESET}\n" "[SUCCESS]" "File/Directory EXISTS"
    else
        printf "${COLORS[RED]}%s %s${RESET}\n" "[ERROR]" "File/Directory NOT FOUND"
        return 1
    fi
    return 0
}
# @description Initialize process.
process_init() {
    local process_name
    local process_id
    process_name="$1"
    process_id=$(date +%s)
    CURRENT_PROCESS="$process_name"
    CURRENT_PROCESS_ID="$process_id"

    #initialize_scripts || { print_message ERROR "Failed to initialize script"; return 1; }
    print_message PROC "Starting process: " "$process_name (ID: $process_id)"
    echo "$process_id:$process_name:started" >> "$PROCESS_LOG"
}
# @description Run process.
# @arg $1 string Process PID.
# @arg $2 string Process name.  
process_end() {
    local exit_code
    local process_name
    local process_id

    # Set the variables
    exit_code=$1
    process_name="$CURRENT_PROCESS"
    process_id="$CURRENT_PROCESS_ID"

    # Add this debug message
    if [[ $DEBUG_MODE == true ]]; then
        print_message DEBUG "Starting process: " "$process_name (Script: $SCRIPT_NAME)"
    fi
    # Check if the process completed successfully
    if [ "$exit_code" -eq 0 ]; then
        print_message PROC "Process completed successfully: " "$process_name (ID: $process_id)"
        echo "$process_id:$process_name:completed" >> "$PROCESS_LOG"
    else
        print_message PROC "ERROR: Process failed: " "$process_name (ID: $process_id, Exit code: $exit_code)"
        echo "$process_id:$process_name:failed:$exit_code" >> "$PROCESS_LOG"
    fi

    print_message INFO "All processes allmost completed....." sleep 5
    # Reset the current process variables
    CURRENT_PROCESS=""
    CURRENT_PROCESS_ID=""
}
# @description Debug function
# @arg $1 string Message.
# @arg $2 string Highlight.
debug() {
    [[ $DEBUG == true ]] && log "DEBUG" "$1" "$2"
} 
# @description Setup error handling
# @noargs
setup_error_handling() {
    set -o errtrace
    trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR
    trap 'exit_handler $?' EXIT
}
# @description Error handler function
# @arg $1 int Exit code
# @arg $2 int Line number
# @arg $3 string Function name
error_handler() {
    local exit_code
    local line_number
    local function_name

    exit_code=$1
    line_number=$2

    # Loop through the call stack to find the first non-lib.sh function
    for ((i=1; i<${#FUNCNAME[@]}; i++)); do
        if [[ "${BASH_SOURCE[i]}" != "${BASH_SOURCE[0]}" ]]; then
            function_name="${FUNCNAME[i]}"
            line_number="${BASH_LINENO[i-1]}"
            break
        fi
    done

    function_name="${function_name:-main}"
    local command="${BASH_COMMAND}"
    print_message ERROR "Error in function '$function_name' on line $line_number: Command '$command' exited with status: " "$exit_code"
    # Store the error information for later use
    ERROR_FUNCTION="$function_name"
    ERROR_LINE="$line_number"
    ERROR_COMMAND="$command"
    ERROR_CODE="$exit_code"
}
# @description Exit handler function
# @arg $1 int Exit code
exit_handler() {
    local exit_code
    exit_code=$1

    print_message INFO "Exit handler called with exit code: " "$exit_code"
    if [ $exit_code -eq 0 ]; then
        print_message INFO "Script execution completed successfully"
    else
        print_message ERROR "Script execution failed with exit code: " "$exit_code"
    fi
}
# @description Cleanup handler
# @param None
# @return None
cleanup_handler() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_message "WARNING" "Script encountered errors. Exit code: ${COLORS[RED]}$exit_code${COLORS[RESET]}"
    else
        verbose_print "Exit code: ${COLORS[GREEN]}$exit_code${COLORS[RESET]}"
        print_message "INFO" "Script completed successfully"
    fi
}
# @description Trap error.
trap_error() {
    local error_message
    error_message="Command '${BASH_COMMAND}' failed with exit code $? in function '${1}' (line ${2})"
    print_message ERROR "Failed: " "$error_message"
    echo "$error_message" > "$ERROR_LOG"
}
# @description Trap exit.
# Read error msg from file (written in error trap)
trap_exit() {
        local result_code
        local error_message

        result_code="$?"
        error_message=""

    # Read error msg from file (written in error trap)
    [[ -f "$ERROR_FILE" ]] && error_message=$(<"$ERROR_FILE") && rm -f "$ERROR_FILE"

    # cleanup

    # When ctrl + c pressed exit without other stuff below
    [[ "$result_code" = "130" ]] && print_message WARNING "Exit..." && exit 1

    # Check if failed and print error
    if [[ "$result_code" -gt "0" ]]; then
        if [[ -n "$error_message" ]]; then
            print_message ERROR "$error_message"
        else
            print_message ERROR "Arch Installation failed"
        fi
        print_message WARNING "For more information see: " "$FILE_LOG"
    fi

    exit "$result_code"
}
# @description Clean up temporary files and reset system state.
cleanup() {
    print_message INFO "Cleaning up...."
    if [[ -d "$SCRIPT_TMP_DIR" ]]; then
        cp -r "$SCRIPT_TMP_DIR" "$SCRIPT_DIR/logs"
        rm -rf "$SCRIPT_TMP_DIR" || print_message WARNING "Failed to remove temporary directory: " "$SCRIPT_TMP_DIR"
        print_message INFO "Cleanup complete."
    fi
    # Add other cleanup tasks here
    print_message DEBUG "Cleanup completed"
}
# @description Load configuration variables.
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_message ERROR "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Source the configuration file to load all variables
    set -o allexport
    source "$CONFIG_FILE"
    set +o allexport

    print_message OK "Configuration loaded successfully"
    return 0
}
# @description Get config value.
# @arg $1 string Key
# @arg $2 string Default value
get_config_value() {
    local key
    local default_value
    local value

    key="$1"
    default_value="${2:-}"

    if [[ -f "$CONFIG_FILE" ]]; then
        value=$(grep "^${key}=" "$CONFIG_FILE" | sed "s/^${key}=//")
        print_message DEBUG "Retrieved from config file: " "$key=$value"
    fi

    if [[ -z "$value" ]]; then
        # Check for in-memory value
        local var_name="CONFIG_${key}"
        value="${!var_name}"
        print_message DEBUG "Retrieved from memory: " "$key=$value"
    fi

    if [[ -z "$value" && -n "$default_value" ]]; then
        value="$default_value"
        print_message DEBUG "Using default value: " "$key=$value"
    fi

    if [[ -z "$value" ]]; then
        print_message WARNING "Key not found in config file or memory: " "$key"
        return 1
    fi

    # Remove surrounding quotes if present
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    print_message DEBUG "Final value for: " "$key=$value"
    echo "$value"
}
# @description Read config file.
# @noargs
read_config() {
    local toml_file="$ARCH_DIR/arch_config.toml"
    local cfg_file="$ARCH_DIR/arch_config.cfg"

    print_message INFO "Reading configuration from $toml_file"

    # Check if the TOML file exists
    if [[ ! -f "$toml_file" ]]; then
        print_message ERROR "TOML configuration file not found: $toml_file"
        return 1
    fi

    # Clear the existing cfg file
    > "$cfg_file"

    # Read the TOML file and write to the cfg file, removing quotes
    while IFS='=' read -r key value; do
        # Remove leading/trailing whitespace from the key
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Remove leading/trailing whitespace and quotes from the value
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//;s/"$//')
        
        echo "${key}=${value}" >> "$cfg_file"
    done < "$toml_file"

    print_message OK "Configuration loaded into: $cfg_file"
}
# @description Set option.
# @arg $1 string Key.
# @arg $2 string Value.
set_option() {
    local key
    local value
    local config_file

    key="$1"
    value="$2"
    config_file="$CONFIG_FILE"

    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_message ACTION "[DRY RUN] Would set: " "$key=$value in $config_file"
    fi

    # Always update the config file, even in DRY_RUN mode
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=.*|$key=$value|" "$config_file"
    else
        echo "$key=$value" >> "$config_file"
    fi

    print_message DEBUG "Updated: " "$key=$value in $config_file"
}
drive_list() {
    print_message DEBUG "Getting the drive list"
    # Check if lsblk command is available
    if ! command -v lsblk >/dev/null 2>&1; then
        print_message ERROR "lsblk command not found. Unable to list drives."
        return 1
    fi
    # Run lsblk and format the output
    if ! mapfile -t drive_info < <(lsblk -ndo NAME,SIZE,MODEL 2>/dev/null); then
        print_message ERROR "Failed to get drive information"
        return 1
    fi
    # Check if we got any drive information
    if [ ${#drive_info[@]} -eq 0 ]; then
        print_message ERROR "No drives found or unable to read drive information"
        return 1
    fi
    # Create an array to store drive names
    #local drives
    drives=()
    # Display the formatted output with numbers
    for i in "${!drive_info[@]}"; do
        show_listitem "$((i+1))) ${drive_info[i]}"
        drives+=("$(echo "${drive_info[i]}" | awk '{print $1}')")
    done
    print_message DEBUG "Drive list completed successfully"
}
# Sets INSTALL_DEVICE in the config file
show_drive_list() {
    local drive_info
    local drives
    local selected
    local selected_drive
    local saved_device

    print_message INFO "Here a list of availble drives"[]
    # run lsblkk and format the output
    mapfile -t drive_info < <(lsblk -ndo NAME,SIZE,MODEL)
    #create an array to store drive names
    drives=()
    #display the formatted output with numbers
    for i in "${!drive_info[@]}"; do
        show_listitem "$((i+1))) ${drive_info[i]}"
        drives+=("$(echo "${drive_info[i]}" | awk '{print $1}')")
    done
    # Ask user to select a drive
    while true; do
        selected=$(ask_question "Enter the number of the drive you want to use:")
        if [[ "$selected" =~ ^[0-9]+$ ]] && ((selected >= 1 && selected <= ${#drives[@]})); then
            selected_drive=${drives[$selected-1]}
            print_message ACTION "You selected drive: " "$selected_drive"
            
            # Export INSTALL_DEVICE here
            export INSTALL_DEVICE="$selected_drive"
            set_option "INSTALL_DEVICE" "$INSTALL_DEVICE" || { print_message ERROR "Failed to set INSTALL_DEVICE"; return 1; }
            print_message ACTION "INSTALL_DEVICE set to: " "$INSTALL_DEVICE"
            break
        else
            print_message WARNING "Invalid selection. Please enter a number between: " "1 and ${#drives[@]}."
        fi
    done


}
# @description Display a formatted list item
# @param $1 The list item to display
show_listitem() {
    local item
    item="$1"
    echo "  $item" | sed 's/^/    /'
}
# @description Ask question.
# @arg $1 string Question
ask_question() {
    local blue
    local nc
    local var

    blue=$'\033[0;94m'
    nc=$'\033[0m'
    read -r -p "${blue}$*${nc} " var
    echo "$var"
}
# Function to read TOML file and update INSTALL_GROUPS
read_toml_and_update_groups() {
    local toml_file="$1"
    local temp_groups=()

    while IFS= read -r line; do
        if [[ $line =~ ^\[([^]]+)\]$ ]]; then
            current_group="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^\"([^\"]+)\"[[:space:]]*=[[:space:]]*\{([^}]+)\}$ ]]; then
            local stage="${BASH_REMATCH[1]}"
            local content="${BASH_REMATCH[2]}"
            INSTALL_SCRIPTS["$stage"]=""
            print_message DEBUG "Processing stage: $stage"
            
            if [[ $content =~ mandatory[[:space:]]*=[[:space:]]*\[([^]]+)\] ]]; then
                IFS=',' read -ra mandatory_scripts <<< "${BASH_REMATCH[1]}"
                for script in "${mandatory_scripts[@]}"; do
                    script=$(echo "$script" | tr -d '"' | xargs)
                    INSTALL_SCRIPTS["$stage"]+="mandatory=$script;"
                done
            fi
            
            if [[ $content =~ optional[[:space:]]*=[[:space:]]*\[([^]]+)\] ]]; then
                IFS=',' read -ra optional_scripts <<< "${BASH_REMATCH[1]}"
                for script in "${optional_scripts[@]}"; do
                    script=$(echo "$script" | tr -d '"' | xargs)
                    INSTALL_SCRIPTS["$stage"]+="optional=$script;"
                done
            fi
        fi
    done < "$toml_file"

    if [[ ${#INSTALL_SCRIPTS[@]} -eq 0 ]]; then
        print_message ERROR "No stages found in TOML file"
        return 1
    fi

    print_message DEBUG "Parsed ${#INSTALL_SCRIPTS[@]} stages"
    for stage in "${!INSTALL_SCRIPTS[@]}"; do
        print_message DEBUG "Stage $stage: ${INSTALL_SCRIPTS[$stage]}"
    done

    return 0
}
# Function to execute commands with error handling
execute_process() {
    local process_name="$1"
    shift
    local use_chroot=false
    local debug=false
    local critical=${critical:-false}
    local error_message="Process failed"
    local success_message="Process completed successfully"
    local exit_code=0
    local commands=()

    while [[ "$1" == --* ]]; do
        case "$1" in
            --use-chroot) use_chroot=true; shift ;;
            --debug) debug=true; shift ;;
            --critical) critical=true; shift ;;
            --error-message) error_message="$2"; shift 2 ;;
            --success-message) success_message="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
    done

    # Collect remaining arguments as commands
    commands=("$@")
    print_message INFO "Starting: $process_name"
    # If no commands provided, return 0
    if [[ ${#commands[@]} -eq 0 ]]; then
        print_message WARNING "No commands provided for execution"
        return 0
    fi
    # Execute commands
    for cmd in "${commands[@]}"; do
        # If DRY_RUN is true, print the command
        if [[ "$DRY_RUN" == true ]]; then
            print_message ACTION "[DRY RUN] Would execute: $cmd"
        else
            # If debug is true, print the command
            if [[ "$debug" == true ]]; then
                print_message DEBUG "Executing: $cmd"
            fi
            # If use_chroot is true, execute the command in chroot
            if [[ "$use_chroot" == true ]]; then
                if ! arch-chroot /mnt /bin/bash -c "$cmd"; then
                    print_message ERROR "${error_message} ${process_name}: $cmd"
                    # If critical is true, handle critical error
                    if [[ "$critical" == true ]]; then
                        handle_critical_error "${error_message} ${process_name}: $cmd"
                        exit_code=1
                        break
                    fi
                fi
            else
                # If use_chroot is false, execute the command in the current shell
                if ! eval "$cmd"; then
                    print_message ERROR "${error_message} ${process_name}: ${cmd}"
                    # If critical is true, handle critical error
                    if [[ "$critical" == true ]]; then
                        handle_critical_error "${error_message} ${process_name} failed: ${cmd}"
                        exit_code=1
                        break
                    fi
                fi
            fi
        fi
    done
    # Print success message if exit code is 0
    if [[ $exit_code -eq 0 ]]; then
        print_message OK "${success_message} ${process_name} completed"
    fi
    return $exit_code
}
# @description Execute scripts for a given stage.
# @arg $1 string Stage (directory name)
# @arg $2 string Script name
execute_script() {
    local stage="$1"
    local script="$2"
    local dry_run="$3"
    local script_path="$SCRIPTS_DIR/$stage/$script"

    if [[ ! -f "$script_path" ]]; then
        print_message WARNING "Script file not found: $script_path"
        return 0  # Return 0 to allow continuation
    fi

    print_message INFO "Executing: $stage/$script"
    print_message DEBUG "Script path: $script_path"
    print_message DEBUG "DRY_RUN value before execution: $DRY_RUN"

    if [[ $dry_run == true ]]; then
        print_message ACTION "[DRY RUN] Would execute: bash $script_path (Script: $script)"
        while IFS= read -r line; do
            if [[ ! -z "$line" && "$line" != \#* ]]; then
                print_message ACTION "[DRY RUN] Would execute: $line"
            fi
        done < "$script_path"
    else
        print_message ACTION "Executing script: $script_path"
        if ! (export DRY_RUN="$dry_run"; bash "$script_path"); then
            print_message ERROR "Failed to execute $script in stage $stage"
            return 1
        fi
    fi

    return 0
}
# @description Run install scripts.
# @arg $1 string Format type
# @arg $2 string Desktop environment
run_install_scripts() {
    local format_type="$1"
    local desktop_environment="$2"
    local dry_run="${3:=false}"
    local mandatory_scripts
    local optional_scripts

    parse_stages_toml

    for stage in "${SORTED_STAGES[@]}"; do
        print_message DEBUG "Processing stage: $stage"
        IFS=';' read -ra stage_scripts <<< "${INSTALL_SCRIPTS[$stage]}"
        mandatory_scripts=()
        optional_scripts=()

        for script_info in "${stage_scripts[@]}"; do
            if [[ $script_info =~ ^(mandatory|optional)=([^=]+)$ ]]; then
                local type="${BASH_REMATCH[1]}"
                local script="${BASH_REMATCH[2]}"
                
                # Handle format_type placeholder
                if [[ $script == *"{format_type}"* ]]; then
                    if [[ -n "${FORMAT_TYPES[$format_type]}" ]]; then
                        IFS=',' read -ra format_scripts <<< "${FORMAT_TYPES[$format_type]}"
                        for format_script in "${format_scripts[@]}"; do
                            if [[ $type == "mandatory" ]]; then
                                mandatory_scripts+=("$format_script")
                            else
                                optional_scripts+=("$format_script")
                            fi
                        done
                        continue
                    else
                        print_message WARNING "Unknown format type: $format_type"
                    fi
                fi
                
                # Handle desktop_environment placeholder
                if [[ $script == *"{desktop_environment}"* ]]; then
                    if [[ -n "${DESKTOP_ENVIRONMENTS[$desktop_environment]}" ]]; then
                        IFS=',' read -ra de_scripts <<< "${DESKTOP_ENVIRONMENTS[$desktop_environment]}"
                        for de_script in "${de_scripts[@]}"; do
                            if [[ $type == "mandatory" ]]; then
                                mandatory_scripts+=("$de_script")
                            else
                                optional_scripts+=("$de_script")
                            fi
                        done
                        continue
                    else
                        print_message WARNING "Unknown desktop environment: $desktop_environment"
                    fi
                fi

                # If no placeholder, add the script as is
                if [[ $type == "mandatory" ]]; then
                    mandatory_scripts+=("$script")
                else
                    optional_scripts+=("$script")
                fi
            fi
        done

        print_message DEBUG "Mandatory scripts for $stage: ${mandatory_scripts[*]}"
        print_message DEBUG "Optional scripts for $stage: ${optional_scripts[*]}"

        for script in "${mandatory_scripts[@]}"; do
            if [[ ! -f "$SCRIPTS_DIR/$stage/$script" ]]; then
                print_message ERROR "Mandatory script not found: $stage/$script"
                return 1
            fi
            if ! execute_script "$stage" "$script" "$dry_run"; then
                print_message ERROR "Failed to execute mandatory script: $stage/$script"
                return 1
            fi
        done

        for script in "${optional_scripts[@]}"; do
            if [[ -f "$SCRIPTS_DIR/$stage/$script" ]]; then
                if should_run_optional_script "$script"; then
                    if ! execute_script "$stage" "$script" "$dry_run"; then
                        print_message WARNING "Failed to execute optional script: $stage/$script"
                    fi
                else
                    print_message INFO "Skipping optional script: $stage/$script"
                fi
            else
                print_message INFO "Optional script not found, skipping: $stage/$script"
            fi
        done
    done
}
# @description Check if an optional script should run.
# @arg $1 string Script name
# @return 0 if the script should run, 1 otherwise   
should_run_optional_script() {
    local script="$1"
    local config_var="INSTALL_$(echo "${script%.*}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    local install_script=$(get_config_value "$config_var" "false")
    [[ "$install_script" == "true" ]]
}
# @description Parse TOML file and populate INSTALL_SCRIPTS
# @arg $1 string Path to the TOML file
# @return 0 on success, 1 on failure
parse_stages_toml() {
    local toml_file="$ARCH_DIR/stages.toml"
    local current_section=""

    declare -gA INSTALL_SCRIPTS
    declare -gA FORMAT_TYPES
    declare -gA DESKTOP_ENVIRONMENTS

    print_message DEBUG "Parsing stages TOML file: $toml_file"

    while IFS= read -r line; do
        if [[ $line =~ ^\[([^]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            print_message DEBUG "Found section: $current_section"
        elif [[ $current_section == "stages" && $line =~ ^\"([^\"]+)\"[[:space:]]*=[[:space:]]*\{([^}]+)\}$ ]]; then
            local stage="${BASH_REMATCH[1]}"
            local content="${BASH_REMATCH[2]}"
            INSTALL_SCRIPTS["$stage"]=""
            print_message DEBUG "Processing stage: $stage"
            
            if [[ $content =~ mandatory[[:space:]]*=[[:space:]]*\[([^]]+)\] ]]; then
                IFS=',' read -ra mandatory_scripts <<< "${BASH_REMATCH[1]}"
                for script in "${mandatory_scripts[@]}"; do
                    script=$(echo "$script" | tr -d '"' | xargs)
                    INSTALL_SCRIPTS["$stage"]+="mandatory=$script;"
                done
            fi
            
            if [[ $content =~ optional[[:space:]]*=[[:space:]]*\[([^]]+)\] ]]; then
                IFS=',' read -ra optional_scripts <<< "${BASH_REMATCH[1]}"
                for script in "${optional_scripts[@]}"; do
                    script=$(echo "$script" | tr -d '"' | xargs)
                    INSTALL_SCRIPTS["$stage"]+="optional=$script;"
                done
            fi
        elif [[ $current_section == "format_types" && $line =~ ^([^=]+)[[:space:]]*=[[:space:]]*\[([^]]+)\]$ ]]; then
            local format_type="${BASH_REMATCH[1]}"
            local scripts="${BASH_REMATCH[2]}"
            FORMAT_TYPES["$format_type"]=$(echo "$scripts" | tr -d '"' | xargs)
            print_message DEBUG "Format type: $format_type, Scripts: ${FORMAT_TYPES[$format_type]}"
        elif [[ $current_section == "desktop_environments" && $line =~ ^([^=]+)[[:space:]]*=[[:space:]]*\[([^]]+)\]$ ]]; then
            local desktop_env="${BASH_REMATCH[1]}"
            local scripts="${BASH_REMATCH[2]}"
            DESKTOP_ENVIRONMENTS["$desktop_env"]=$(echo "$scripts" | tr -d '"' | xargs)
            print_message DEBUG "Desktop environment: $desktop_env, Scripts: ${DESKTOP_ENVIRONMENTS[$desktop_env]}"
        fi
    done < "$toml_file"

    # Print debug information
    print_message DEBUG "Parsed ${#INSTALL_SCRIPTS[@]} stages"
    for stage in "${!INSTALL_SCRIPTS[@]}"; do
        print_message DEBUG "Stage $stage: ${INSTALL_SCRIPTS[$stage]}"
    done

    print_message DEBUG "Parsed ${#FORMAT_TYPES[@]} format types"
    for format_type in "${!FORMAT_TYPES[@]}"; do
        print_message DEBUG "Format type $format_type: ${FORMAT_TYPES[$format_type]}"
    done

    print_message DEBUG "Parsed ${#DESKTOP_ENVIRONMENTS[@]} desktop environments"
    for desktop_env in "${!DESKTOP_ENVIRONMENTS[@]}"; do
        print_message DEBUG "Desktop environment $desktop_env: ${DESKTOP_ENVIRONMENTS[$desktop_env]}"
    done

    return 0
}
# @description Run command with dry run support.
# @arg DRY_RUN bool
# @arg $1 string Command
run_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_message ACTION "[DRY RUN] Would execute: " "$*"
        return 0
    else
        if ! "$@"; then
            print_message ERROR "Command failed: " "$*"
            return 1
        fi
    fi
}
# @description Check if the user is root.
root_check() {
    if [[ $EUID -ne 0 ]]; then
        print_message ERROR "This script must be run as root"
        return 1
    fi
}
# @description Check if the system is Arch Linux.
arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        print_message ERROR "This script must be run on Arch Linux"
        return 1
    fi
}
# @description Check if pacman is installed.
pacman_check() {
    if ! command -v pacman &> /dev/null; then
        print_message ERROR "Pacman is not installed"
        return 1
    fi
}
# @description Check if docker is installed.
docker_check() {
    if command -v docker &> /dev/null; then
        print_message WARNING "Docker is installed. This might interfere with the installation process."
    fi
}
# @description Determine the microcode.
# @return string Microcode
# @noargs
determine_microcode() {
    local cpu_vendor

    # Get CPU vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

    case "$cpu_vendor" in
        GenuineIntel)
            echo "intel"
            ;;
        AuthenticAMD)
            echo "amd"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}
# @description Backup config file.
# @arg $1 string Config file
backup_config() {
    local config_file="$1"
    local backup_dir="$ARCH_DIR/backups"
    local timestamp
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    mkdir -p "$backup_dir"
    cp "$config_file" "$backup_dir/$(basename "$config_file").backup.$timestamp"
    print_message INFO "Backup of $config_file created at $backup_dir/$(basename "$config_file").backup.$timestamp"
}
# @description Backup fstab.
# @arg $1 string Fstab file 
# @arg string Mount point
# @arg string Backup directory
# @arg string Backup file
# @return 0 on success, 1 on failure
backup_fstab() {
    local fstab_file="$1"
    local mount_point="/mnt"
    local backup_dir="${mount_point}/etc/fstab.backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/fstab_backup_${timestamp}"

    print_message INFO "Backing up fstab"

    # Check if mount point exists and is accessible
    if [ ! -d "$mount_point" ] || [ ! -w "$mount_point" ]; then
        print_message WARNING "Mount point $mount_point is not accessible. Skipping fstab backup."
        return 0
    fi

    # Create backup directory if it doesn't exist
    if ! mkdir -p "$backup_dir"; then
        print_message ERROR "Failed to create backup directory: $backup_dir"
        return 1
    fi

    # Check if fstab file exists
    if [ ! -f "$fstab_file" ]; then
        print_message WARNING "fstab file does not exist: $fstab_file"
        return 0
    fi

    # Create backup
    if cp "$fstab_file" "$backup_file"; then
        print_message OK "fstab backed up to: $backup_file"
    else
        print_message ERROR "Failed to backup fstab"
        return 1
    fi

    # Keep only the last 3 backups
    local excess_backups=$(ls -t "${backup_dir}/fstab_backup_"* 2>/dev/null | tail -n +4)
    if [ -n "$excess_backups" ]; then
        print_message INFO "Removing old backups"
        echo "$excess_backups" | xargs rm -f
    fi

    return 0
}
# @description Handle critical error.
# @arg $1 string Error message
handle_critical_error() {
    local error_message="$1"
    
    print_message ERROR "CRITICAL ERROR: $error_message"
    print_message INFO "Cleaning up..."
    cleanup
    umount -R /mnt || true
    print_message INFO "Cleanup complete."
    print_message INFO "Installation aborted due to critical error."
    sleep 5
    exit 1
}
# @description Check disk space
# @arg $1 string Mount point to check
# @return 0 if space is sufficient, 1 if space is low
check_disk_space() {
    local mount_point="$1"
    local available_space
    local total_space
    local used_percentage

    available_space=$(df -k "$mount_point" | awk 'NR==2 {print $4}')
    total_space=$(df -k "$mount_point" | awk 'NR==2 {print $2}')
    used_percentage=$(df -h "$mount_point" | awk 'NR==2 {print $5}' | sed 's/%//')

    print_message INFO "Disk space check for $mount_point:"
    print_message INFO "Total space: $(( total_space / 1024 )) MB"
    print_message INFO "Available space: $(( available_space / 1024 )) MB"
    print_message INFO "Used percentage: $used_percentage%"

    if [[ $used_percentage -gt 90 ]]; then
        print_message WARNING "Disk space is critically low on $mount_point"
        return 1
    elif [[ $used_percentage -gt 80 ]]; then
        print_message WARNING "Disk space is running low on $mount_point"
    fi

    return 0
}
ensure_log_directory() {
    local log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            print_message ERROR "Failed to create log directory: $log_dir" | >&2
            return 1
        }
    fi
}
