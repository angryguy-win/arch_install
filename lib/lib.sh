#!/bin/bash
# Lib.sh file
# Location: /lib/lib.sh
# Author: ssnow
# Date: 2024
# Description: This file contains all the functions used in the install script
#              and other scripts.

set -eo pipefail

# Use the values set in install.sh, or use defaults if not set
# DRY_RUN_GLOBAL="${DRY_RUN:-false}"  #<-- global var
DRY_RUN="${DRY_RUN:-false}"
DEBUG_MODE="${DEBUG_MODE:-false}"
VERBOSE="${VERBOSE:-false}"

# Script-related variables
SCRIPT_NAME=$(basename "$0")
SCRIPT_VERSION="1.5.0"

# Log file setup
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/arch_install.log"
PROCESS_LOG="$LOG_DIR/process.log"

if [[ ! -d "$LOG_DIR" ]]; then
    # Create log directory and files if they don't exist
    printf "%b\n" "Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR" || { echo "Failed to create log directory: $LOG_DIR"; exit 1; }
fi
if [[ ! -f "$LOG_FILE" ]]; then
    printf "%b\n" "Creating log file: $LOG_FILE"
    touch "$LOG_FILE" || { echo "Failed to create log file: $LOG_FILE"; exit 1; }
fi
if [[ ! -f "$PROCESS_LOG" ]]; then
    printf "%b\n" "Creating process log file: $PROCESS_LOG"
    touch "$PROCESS_LOG" || { echo "Failed to create process log file: $PROCESS_LOG"; exit 1; }
fi

# @description Color codes
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

# @description Debug information
# @noargs
debug_info() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "DEBUG: DRY_RUN is set to $DRY_RUN"
        echo "DEBUG: VERBOSE is set to $VERBOSE"
        echo "DEBUG: DEBUG_MODE is set to $DEBUG_MODE"
        echo "DEBUG: LOG_DIR is set to $LOG_DIR"
        echo "DEBUG: CONFIG_FILE is set to $CONFIG_FILE"
    fi
}

# @description Error handling
trap 'log "ERROR" "An error occurred. Exiting."; exit 1' ERR

# @description Displays Arch logo
# @noargs
show_logo () {
    local logo_message
    local border
    local text_color
    local logo_message_color

    # This will display the Logo banner and a message
    logo_message=$1
    border=${COLORS[BLUE]}
    text_color=${COLORS[GREEN]}
    logo_message_color=${COLORS[GREEN]}
printf "%b" " 
${border}-------------------------------------------------------------------------
${logo_message_color}
                 \u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2588 \u2588\u2588\u2557  \u2588\u2588\u2557
                \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2551  \u2588\u2588\u2551
                \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2551     \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551 
                \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2551     \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2551
                \u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2551  \u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2551  \u2588\u2588\u2551
                \u255a\u2550\u255d  \u255a\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u255d
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
    local level=$1
    shift
    local message=${*}
    local timestamp
    local prefix="[$level]"
    local log_entry

    # Set the Variables
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Construct the log message without color codes
    local log_entry="${timestamp} ${prefix} ${message}"

    # Use tee to write to both console and log file
    printf "%b\n" "$log_entry" >> $LOG_FILE 
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
    local timestamp
    
    timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"


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
    printf "%b\n" "$formatted_message" | tee -a >(sed -E "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g" >> "$PROCESS_LOG")
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
show_system_info() {
    # Define variables
    local INSTALL_SCRIPT
    local ARCH_CONFIG_TOML
    local ARCH_CONFIG_CFG
    local LOG_FILE
    local PROCESS_LOG
    local SCRIPT_DIR
    local total_ram_kb
    local RAM_AMOUNT
    local CPU_MODEL
    local CPU_CORES
    local CPU_THREADS


    # Set the variables 
    INSTALL_SCRIPT="$ARCH_DIR/install.sh"
    ARCH_CONFIG_TOML="$ARCH_DIR/arch_config.toml"
    ARCH_CONFIG_CFG="$ARCH_DIR/arch_config.cfg"
    LOG_FILE="$LOG_DIR/arch_install.log"
    PROCESS_LOG="$LOG_DIR/process.log"
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
        #set_option "RAM_AMOUNT" "$RAM_AMOUNT" || { print_message ERROR "Failed to set RAM_AMOUNT"; return 1; }
    else
        print_message WARNING "Unable to determine RAM amount"
    fi
}
# @description Get CPU information
# @noargs   
cpu() {
    if CPU_MODEL=$(lscpu | awk -F': +' '/Model name/ {print $2}'); then
        print_message INFO "CPU Model: " "$CPU_MODEL"
        #set_option "CPU_MODEL" "$CPU_MODEL" || { print_message ERROR "Failed to set CPU_MODEL"; return 1; }
    else
        print_message WARNING "Unable to determine CPU model"
    fi

    if CPU_CORES=$(nproc 2>/dev/null); then
        print_message INFO "CPU Cores: " "$CPU_CORES"
        #set_option "CPU_CORES" "$CPU_CORES" || { print_message ERROR "Failed to set CPU_CORES"; return 1; }
    else
        print_message WARNING "Unable to determine CPU core count"
    fi

    if CPU_THREADS=$(lscpu | awk '/^CPU\(s\):/ {print $2}'); then
        print_message INFO "CPU Threads: " "$CPU_THREADS"
        #set_option "CPU_THREADS" "$CPU_THREADS" || { print_message ERROR "Failed to set CPU_THREADS"; return 1; }
    else
        print_message WARNING "Unable to determine CPU thread count"
    fi
}
gpu_type() {
    local gpu_type
    # gpu_type=$(lspci | grep -E "VGA|3D|Display" | awk -F': ' '{print $2}' | awk -F' (' '{print $1}')
    gpu_type=$(lspci | grep -E "VGA|3D|Display" | awk -F'[][]' '/AMD|NVIDIA|Intel/ {print $2 " " $4}')
    #set_option "GPU_TYPE" "$gpu_type" || { print_message ERROR "Failed to set GPU_TYPE"; return 1; }
    print_message INFO "GPU Type: " "$gpu_type"
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
# @arg $1 string Process name.
# @noargs
# @description Initialize process.
# @arg $1 string Process name.
# @noargs
process_init() {
    local process_name
    local process_id
    process_name="$1"
    process_id=$(date +%s)
    CURRENT_PROCESS="$process_name"
    CURRENT_PROCESS_ID="$process_id"

    printf "%b\n" "$process_id:$process_name:started" >> "$PROCESS_LOG"
    START_TIMESTAMP=$(date -u +"%F %T")
    print_message DEBUG "Start time: " "$START_TIMESTAMP"

    #init_log_trace true

    # Set up error handling for this process
    set -o errtrace
    trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

    print_message PROC "Starting process: " "$process_name (ID: $process_id) $START_TIMESTAMP"
    print_message DEBUG "======================= Starting $process_name  ======================="
    show_logo "$process_name"
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
        print_message DEBUG "Ending process: " "$process_name (Script: $SCRIPT_NAME)"
    fi
    # Check if the process completed successfully
    if [ "$exit_code" -eq 0 ]; then
        print_message PROC "Process completed successfully: " "$process_name (ID: $process_id)"
        printf "%b\n" "$process_id:$process_name:completed" >> "$PROCESS_LOG"
    else
        print_message PROC "ERROR: Process failed: " "$process_name (ID: $process_id, Exit code: $exit_code)"
        printf "%b\n" "$process_id:$process_name:failed:$exit_code" >> "$PROCESS_LOG"
    fi

    #init_log_trace false
    trap 'exit_handler $?' EXIT

    END_TIMESTAMP=$(date -u +"%F %T")
    INSTALLATION_TIME=$(date -u -d @$(($(date -d "$END_TIMESTAMP" '+%s') - $(date -d "$START_TIMESTAMP" '+%s'))) '+%T')
    printf "%b\n" " Process start ${WHITE}$START_TIMESTAMP${NC}, end ${WHITE}$END_TIMESTAMP${NC}, time ${WHITE}$INSTALLATION_TIME${NC}"

    print_message DEBUG "============= Ending $process_name ============="

    print_message INFO "All processes allmost completed....." 
    sleep 2
    # Reset the current process variables
    CURRENT_PROCESS=""
    CURRENT_PROCESS_ID=""
}
# @description Debug function
# @arg $1 string Message.
# @arg $2 string Highlight.
debug() {
    [ $DEBUG == true ] && log "DEBUG" "$1" "$2"
}
# @description Initialize log trace.
# @arg $1 bool Enable   
init_log_trace() {
    local ENABLE="$1"
    if [ "$ENABLE" == "true" ]; then
        set -o xtrace
    fi
}
# @description Exit handler
# @arg $1 int Exit code
exit_handler() {
    local exit_code
    exit_code=$1

    print_message INFO "Exit handler called with exit code: " "$exit_code"
    if [ "$exit_code" -eq 0 ]; then
        print_message INFO "Script execution completed successfully"
    else
        print_message ERROR "Script execution failed with exit code: " "$exit_code"
    fi
}
# @description Error handler function
# @arg $1 int Exit code
# @arg $2 int Line number
# @arg $3 string Function name
# shellcheck disable=SC2034
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
# @description Cleanup handler
# @param None
# @return None
cleanup_handler() {
    local exit_code
    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        print_message "WARNING" "Script encountered errors. Exit code: ${COLORS[RED]}$exit_code${COLORS[RESET]}"
    else
        verbose_print "Exit code: ${COLORS[GREEN]}$exit_code${COLORS[RESET]}"
        print_message "INFO" "Script completed successfully"
    fi
}
# @description Clean up temporary files and reset system state.
cleanup() {
    print_message INFO "Cleaning up...."
    if [ -d "$SCRIPT_TMP_DIR" ]; then
        cp -r "$SCRIPT_TMP_DIR" "$SCRIPT_DIR/logs"
        rm -rf "$SCRIPT_TMP_DIR" || print_message WARNING "Failed to remove temporary directory: " "$SCRIPT_TMP_DIR"
        print_message INFO "Cleanup complete."
    fi
    # Add other cleanup tasks here
    print_message DEBUG "Cleanup completed"
}
# @description Load configuration variables.
# @description Load configuration variables.
# shellcheck source=../../config_file
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_message ERROR "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Source the configuration file to load all variables
    # This reads the config file and sets the variables in the current shell
    set -o allexport
    . "$CONFIG_FILE"
    set +o allexport

    # Set default values for variables that might not be in the config file
    # Read the configuration file line by line
    print_message DEBUG "Exported variable: "
    while IFS='=' read -r key value; do
        # Trim whitespace and sanitize
        key=$(sanitize "$(trim "$key")")
        value=$(sanitize "$(trim "$value")")
        # Trim whitespace
        #key=$(echo "$key" | xargs)
        #value=$(echo "$value" | xargs)

        # Skip empty lines and comments
        [[ -z "$key" || "$key" == \#* ]] && continue

        # Export the variable
        export "$key"="$value"
        print_message DEBUG "$key=$value"
    done < "$CONFIG_FILE"

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

    if [ -f "$CONFIG_FILE" ]; then
        value=$(grep "^${key}=" "$CONFIG_FILE" | sed "s/^${key}=//")
        print_message DEBUG "Retrieved from config file: " "$key=$value"
    fi

    if [ -z "$value" ]; then
        # Check for in-memory value
        local var_name="CONFIG_${key}"
        value="${!var_name}"
        print_message DEBUG "Retrieved from memory: " "$key=$value"
    fi

    if [ -z "$value" ] && [ -n "$default_value" ]; then
        value="$default_value"
        print_message DEBUG "Using default value: " "$key=$value"
    fi

    if [ -z "$value" ]; then
        print_message WARNING "Key not found in config file or memory: " "$key"
        return 1
    fi

    # Remove surrounding quotes if present
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"

    print_message DEBUG "Final value for: " "$key=$value"
    printf "%b\n" "$value"
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
    true > "$cfg_file"

    # Read the TOML file and write to the cfg file, removing quotes
    while IFS='=' read -r key value; do
        # Remove leading/trailing whitespace from the key
        key=$(printf "%b" "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        
        # Remove leading/trailing whitespace and quotes from the value
        value=$(printf "%b" "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//;s/"$//')
        
        printf "%b\n" "${key}=${value}" >> "$cfg_file"
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
    value=$(sanitize "$value")

    print_message ACTION "Setting: " "$key=$value in $config_file"

    # Always update the config file, even in DRY_RUN mode
    if grep -q "^$key=" "$config_file"; then
        sed -i "s|^$key=.*|$key=$value|" "$config_file"
    else
        printf "%b\n" "$key=$value" >> "$config_file"
    fi

    print_message DEBUG "Updated: " "$key=$value in $config_file"
}
# @description Get the drive list
# @noargs
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
        drives+=("$(printf "%b" "${drive_info[i]}" | awk '{print $1}')")
    done
    print_message DEBUG "Drive list completed successfully"
}
# @description Show the drive list
# @noargs
show_drive_list() {
    local drive_info
    local drives
    local selected
    local selected_drive

    print_message INFO "Here is a list of available drives:"
    # Run lsblk and format the output
    mapfile -t drive_info < <(lsblk -ndo NAME,SIZE,MODEL)
    # Create an array to store drive names
    drives=()
    # Display the formatted output with numbers
    for i in "${!drive_info[@]}"; do
        show_listitem "$((i+1))) ${drive_info[i]}"
        drives+=("/dev/$(printf "%b" "${drive_info[i]}" | awk '{print $1}')")
    done
    # Ask user to select a drive
    while true; do
        selected=$(ask_question "Enter the number of the drive you want to use:")
        if [[ "$selected" =~ ^[0-9]+$ ]] && ((selected >= 1 && selected <= ${#drives[@]})); then
            selected_drive=${drives[$selected-1]}
            selected_drive=$(sanitize "$selected_drive")
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
    printf "%b\n"   "  $item" | sed 's/^/    /'
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
    printf "%s\n" "$(sanitize "$(trim "$var")")"
}
# @description Execute commands with error handling
# @arg $1 string Process name
# @arg $@ string Commands to execute
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
            *) printf "%b\n" "Unknown option: $1"; return 1 ;;
        esac
    done

    # Collect remaining arguments as commands
    if [[ $# -eq 1 && "${1}" == *$'\n'* ]]; then
        # If a single argument contains newlines, split it into an array
        IFS=$'\n' read -rd '' -a commands <<< "$1"
    else
        # Otherwise, treat all arguments as separate commands
        commands=("$@")
    fi

    print_message INFO "Starting: $process_name"
    
    # If no commands provided, return 0
    if [[ ${#commands[@]} -eq 0 ]]; then
        print_message WARNING "No commands provided for execution"
        return 0
    fi
    
    # Execute commands
    for cmd in "${commands[@]}"; do
        cmd=$(sanitize "$cmd") # Sanitize the command this needs testing
        if [[ "$DRY_RUN" == true ]]; then
            print_message ACTION "[DRY RUN] Would execute: $cmd"
        else
            if [[ "$debug" == true ]]; then
                print_message DEBUG "Executing: $cmd"
            fi
            
            if [[ "$use_chroot" == true ]]; then
                if ! arch-chroot /mnt /bin/bash -c "$cmd"; then
                    print_message ERROR "${error_message} ${process_name}: $cmd"
                    if [[ "$critical" == true ]]; then
                        handle_critical_error "${error_message} ${process_name}: $cmd"
                        exit_code=1
                        break
                    fi
                fi
            else
                if ! eval "$cmd"; then
                    print_message ERROR "${error_message} ${process_name} failed: ${cmd}"
                    if [[ "$critical" == true ]]; then
                        handle_critical_error "${error_message} ${process_name} failed: ${cmd}"
                        exit_code=1
                        break
                    fi
                fi
            fi
        fi
    done
    
    if [[ $exit_code -eq 0 ]]; then
        print_message OK "${success_message} ${process_name} completed"
    fi
    return $exit_code
}
# @description Execute step.
# @arg $1 string Step
execute_step() {
    local STEP="$1"
    eval "$STEP"
    printf "%b\n" "${BLUE}# ${STEP} step${NC}"
}
# @description Process installation stages.
# @arg $1 string Format type
# @arg $2 string Desktop environment
process_installation_stages() {
    local start_from="$1"
    local desktop_environment="$2"
    local stage_name
    local stage_type
    local scripts
    local script
    local script_path
    local start_processing=false

    # Define the stages and their corresponding scripts
    declare -A stages=(
        ["1-pre,o"]="run-checks.sh"
        ["1-pre,m"]="pre-setup.sh"
        ["2-drive,m"]="partition.sh format.sh"
        ["3-base,m"]="bootstrap-pkgs.sh generate-fstab.sh"
        ["4-post,o"]="terminal.sh"
        ["4-post,m"]="system-config.sh system-pkgs.sh"
        ["5-desktop,m"]="{desktop_environment}.sh"
        ["6-final,m"]="last-cleanup.sh"
        ["7-post-setup,o"]="post-setup.sh"
    )

    # Process installation stages
    for stage in $(printf "%s\n" "${!stages[@]}" | sort); do
        stage_name="${stage%,*}"
        stage_type="${stage##*,}"

        # Start processing from the specified stage
        if [[ "$stage_name" == "$start_from" ]]; then
            start_processing=true
        fi

        # Skip stages until the start_from stage is reached
        if [[ "$start_processing" == false ]]; then
            continue
        fi

        # Check if the stage directory exists
        [[ ! -d "${SCRIPTS_DIR}/${stage_name}" ]] && {
            print_message WARNING "Stage directory not found: ${SCRIPTS_DIR}/${stage_name}"
            continue
        }

        # Read the scripts into an array    
        IFS=' ' read -ra scripts <<< "${stages[$stage]}"
        for script in "${scripts[@]}"; do
            script=${script//\{desktop_environment\}/$desktop_environment}
            script_path="${SCRIPTS_DIR}/${stage_name}/${script}"

            print_message INFO "Executing: ${stage_name}/${script}"

            # Check if the script exists
            [[ ! -f "$script_path" ]] && {
                print_message ERROR "Script not found: $script_path"
                print_message DEBUG "Directory contents: $(ls -la "$(dirname "$script_path")")"
                return 1
            }
            # Execute the script
            if bash "$script_path"; then
                print_message ACTION "Successfully executed: $script_path"
            else
                print_message ERROR "Failed to execute: $script_path"
                return 1
            fi
        done
    done

    return 0
}
# @description Run command with dry run support.
# @arg DRY_RUN bool
# @description Check if dialog is installed.
# @description Check if dialog is installed.
# @return 0 if dialog is installed, 1 if not
check_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        print_message WARNING "dialog is not installed. Attempting to install it..."
        if command -v pacman >/dev/null 2>&1; then
            if ! sudo pacman -Sy --noconfirm dialog; then
                print_message WARNING "Failed to install dialog. Falling back to basic input method."
                return 1
            fi
        elif command -v apt-get >/dev/null 2>&1; then
            if ! (sudo apt-get update && sudo apt-get install -y dialog); then
                print_message WARNING "Failed to install dialog. Falling back to basic input method."
                return 1
            fi
        else
            print_message WARNING "Unable to install dialog. Falling back to basic input method."
            return 1
        fi
    fi
    return 0
}
# @description Ask for password.
# @return 0 on success, 1 on failure
ask_for_password() {
    if check_dialog; then
        password=$(dialog --stdout --password --title "Enter admin password" 0 0) || exit 1
        clear
        : ${password:?"password cannot be empty"}
        password2=$(dialog --stdout --password --title "Retype admin password" 0 0) || exit 1
        clear
        [[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )
        set_option "PASSWORD" "$password"
        devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
        device=$(dialog --stdout --menu "Select installation disk" 0 0 0 ${devicelist}) || exit 1
        clear
        set_option "DEVICE" "$device"
    else
        # Fallback to basic input method
        read -s -p "Enter admin password: " password
        echo
        read -s -p "Retype admin password: " password2
        echo
        [[ "$password" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )
        : ${password:?"password cannot be empty"}
        
        echo "Available devices:"
        lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | nl
        read -p "Enter the number of the device you want to use: " device_number
        device=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | sed -n "${device_number}p" | awk '{print $1}')
    fi

    # Export the variables for use in other parts of the script
    export PASSWORD="$password"
    export DEVICE="$device"
}
check_password_complexity() {
    local password="$1"
    local min_length=8
    local min_numbers=4
    local special_chars='!@#$%^&*'

    if [ ${#password} -lt $min_length ]; then
        print_message WARNING "Password must be at least $min_length characters long."
        return 1
    fi

    if ! [[ "$password" =~ [0-9] ]] || [ "$(echo "$password" | tr -cd '0-9' | wc -c)" -lt $min_numbers ]; then
        print_message WARNING "Password must contain at least $min_numbers numbers."
        return 1
    fi

    if ! [[ "$password" =~ [$special_chars] ]]; then
        print_message WARNING "Password must contain at least one special character ($special_chars)."
        return 1
    fi

    return 0
}
generate_encryption_key() {
    local key=$(openssl rand -base64 32)
    print_message INFO "IMPORTANT: Save this encryption key in a safe place. It will not be saved anywhere else."
    print_message INFO "Encryption Key: $key"
    print_message INFO "You can use this key to recover your data if you forget your password."
    print_message ACTION "Press any key to continue..."
    read -n 1 -s
}
# Function: sanitize_variable
sanitize() {
    local variable="$1"
    variable=$(echo "$variable" | sed "s/![^ ]*//g")      # Remove disabled
    variable=$(echo "$variable" | sed -r "s/ {2,}/ /g")   # Remove unnecessary whitespaces
    variable=$(echo "$variable" | sed 's/^[[:space:]]*//') # Trim leading spaces
    variable=$(echo "$variable" | sed 's/[[:space:]]*$//') # Trim trailing spaces
    echo "$variable"
}
# Function: trim_variable
trim() {
    local variable="$1"
    variable=$(echo "$variable" | sed 's/^[[:space:]]*//') # Trim leading spaces
    variable=$(echo "$variable" | sed 's/[[:space:]]*$//') # Trim trailing spaces
    echo "$variable"
}
# Function: swap_file
swap_file() {
    if [[ -n "$SWAP_SIZE" ]]; then
        fallocate -l "${SWAP_SIZE}G" /mnt/swapfile
        chmod 600 /mnt/swapfile
        mkswap /mnt/swapfile
        swapon /mnt/swapfile
    fi
}
run_command() {
    if [ "$DRY_RUN" == "true" ]; then
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
    if [ $EUID -ne 0 ]; then
        print_message ERROR "This script must be run as root"
        return 1
    fi
}
# @description Check if the system is Arch Linux.
arch_check() {
    if [ ! -e /etc/arch-release ]; then
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
            printf %s "intel"
            ;;
        AuthenticAMD)
            printf %s "amd"
            ;;
        *)
            printf %s "unknown"
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
    local timestamp
    local backup_file="${backup_dir}/fstab_backup_${timestamp}"
    local excess_backups

    timestamp=$(date +"%Y%m%d_%H%M%S")
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
    #excess_backups=$(ls -t "${backup_dir}/fstab_backup_"* 2>/dev/null | tail -n +4)
    excess_backups=$(find "${backup_dir}" -name "fstab_backup_*" -type f -printf '%T@ %p\n' | sort -rn | tail -n +4 | cut -d' ' -f2-)
    if [ -n "$excess_backups" ]; then
        print_message INFO "Removing old backups"
        printf "%s\n" "$excess_backups" | xargs rm -f
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
# @description Check for missing required scripts.
# @return 0 if all scripts are present, 1 if any are missing
# shellcheck disable=SC2034
check_required_scripts() {
    local missing_required_scripts=()
    local missing_optional_scripts=()
    print_message DEBUG "=== Checking for missing required scripts ==="
    # Check for missing required scripts
    for stage in "${!INSTALL_SCRIPTS[@]}"; do
        local stage_name="${stage%,*}"
        local script_type="${stage##*,}"
        print_message DEBUG "  Stage: $stage_name ($script_type)"
        # Get the scripts for the current stage and split them into an array
        IFS=' ' read -ra scripts <<< "${INSTALL_SCRIPTS[$stage]}"
        # Loop through each script in the stage
        for script in "${scripts[@]}"; do
            print_message DEBUG "    Checking script: $script"
            # Check if the script is a format script
            if [[ "$script" == *"{format_type}"* ]]; then
                # Get the format scripts for the current format and split them into an array
                # if you "" this it will break the script
                local format_scripts=(${FORMAT_TYPES[$FORMAT_TYPE]})
                # Loop through each format script in the array
                for format_script in "${format_scripts[@]}"; do
                    if [[ ! -f "$SCRIPTS_DIR/$stage_name/$format_script" ]]; then
                        if [[ "$script_type" == "m" ]]; then
                            missing_required_scripts+=("$stage_name/$format_script")
                        else
                            missing_optional_scripts+=("$stage_name/$format_script")
                        fi
                    fi
                done
            # Check if the script is a desktop environment script
            elif [[ "$script" == *"{desktop_environment}"* ]]; then
                # Get the desktop environment script for the current desktop environment
                local de_script="${DESKTOP_ENVIRONMENTS[$DESKTOP_ENVIRONMENT]}"
                # Check if the script file exists
                if [[ ! -f "$SCRIPTS_DIR/$stage_name/$de_script" ]]; then
                    if [[ "$script_type" == "m" ]]; then
                        missing_required_scripts+=("$stage_name/$de_script")
                    else
                        missing_optional_scripts+=("$stage_name/$de_script")
                    fi
                fi
            # Check if the script is a generic script
            else
                # Check if the script file exists
                if [[ ! -f "$SCRIPTS_DIR/$stage_name/$script" ]]; then
                    if [[ "$script_type" == "m" ]]; then
                        missing_required_scripts+=("$stage_name/$script")
                    else
                        missing_optional_scripts+=("$stage_name/$script")
                    fi
                fi
            fi
        done
    done

    # Check for missing required scripts
    if [[ ${#missing_required_scripts[@]} -gt 0 ]]; then
        print_message ERROR "The following required scripts are missing:"
        # Print the missing required scripts
        for script in "${missing_required_scripts[@]}"; do
            print_message ERROR "  - $script"
        done
        return 1
    fi

    # Check for missing optional scripts
    if [[ ${#missing_optional_scripts[@]} -gt 0 ]]; then
        print_message WARNING "The following optional scripts are missing:"
        # Print the missing optional scripts
        for script in "${missing_optional_scripts[@]}"; do
            print_message WARNING "  - $script"
        done
    fi

    return 0
}
# @description Check internet connection.   
# @return 0 if internet connection is available, 1 if not
check_internet_connection() {
    print_message INFO "Checking internet connection..."
    if ping -c 1 archlinux.org &> /dev/null; then
        print_message OK "Internet connection is available"
    else
        print_message ERROR "No internet connection. Please check your network settings."
        exit 1
    fi
}
# @description Ask for password.
# @arg $1 string Password name
# @arg $2 string Password variable
# @return 0 on success, 1 on failure
ask_password() {
    local password_name="$1"
    local password_variable="$2"
    local password1 password2

    while true; do
        printf "Type %s password: " "$password_name" >&2
        IFS= read -r password1 </dev/tty
        printf "\n" >&2
        printf "Retype %s password: " "$password_name" >&2
        IFS= read -r password2 </dev/tty
        printf "\n" >&2

        if [ "$password1" = "$password2" ]; then
            # Use indirect expansion to set the password variable
            printf -v "$password_variable" "%s" "$password1"
            break
        else
            printf "%s passwords don't match. Please try again.\n" "$password_name" >&2
        fi
    done

    set_option PASSWORD "${!password_variable}"
}
# @description Configure network.
# @return 0 on success, 1 on failure
configure_network() {
    if [ -n "$WIFI_INTERFACE" ]; then
        iwctl --passphrase "$WIFI_KEY" station "$WIFI_INTERFACE" connect "$WIFI_ESSID"
        sleep 10
    fi

    # only one ping -c 1, ping gets stuck if -c 5
    if ! ping -c 1 -i 2 -W 5 -w 30 "$PING_HOSTNAME"; then
        print_message ERROR "Network ping check failed. Cannot continue."
        return 1
    fi
}
# @description Get system facts.
# @return 0 on success, 1 on failure
facts_commons() {

    if lscpu | grep -q "GenuineIntel"; then
        CPU_VENDOR="intel"
    elif lscpu | grep -q "AuthenticAMD"; then
        CPU_VENDOR="amd"
    else
        CPU_VENDOR=""
    fi
    set_option "CPU_VENDOR" "$CPU_VENDOR"

    if lspci -nn | grep "\[03" | grep -qi "intel"; then
        GPU_VENDOR="intel"
    elif lspci -nn | grep "\[03" | grep -qi "amd"; then
        GPU_VENDOR="amd"
    elif lspci -nn | grep "\[03" | grep -qi "nvidia"; then
        GPU_VENDOR="nvidia"
    else
        GPU_VENDOR=""
    fi
    set_option "GPU_VENDOR" "$GPU_VENDOR"

    INITRD_MICROCODE=""
    if [ "$CPU_VENDOR" == "intel" ]; then
            INITRD_MICROCODE="intel-ucode.img"
        elif [ "$CPU_VENDOR" == "amd" ]; then
            INITRD_MICROCODE="amd-ucode.img"
        fi
    set_option "INITRD_MICROCODE" "$INITRD_MICROCODE"

    USER_NAME_INSTALL="$(whoami)"
    if [ "$USER_NAME_INSTALL" == "root" ]; then
        SYSTEM_INSTALLATION="true"
    else
        SYSTEM_INSTALLATION="false"
    fi
    set_option "SYSTEM_INSTALLATION" "$SYSTEM_INSTALLATION"
}
# @description Check disk space
# @arg $1 string Mount point to check
# @description Ensure log directory exists.
# @return 0 on success, 1 on failure
ensure_log_directory() {
    local log_dir

    log_dir=$(dirname "$LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        printf "%b\n" "Creating log directory: $log_dir"
        mkdir -p "$log_dir" || {
            print_message ERROR "Failed to create log directory: $log_dir"  >&2
            return 1
        }
    fi
}
# @description Initialize logging to capture all console output
# @arg $1 bool Enable logging
# @arg $2 string Log file path
init_log_file() {
    local enable_logging="$1"
    local log_file="$2"
    if [ "$enable_logging" == "true" ]; then
        # Ensure the log directory exists
        ensure_log_directory
        # Redirect stdout and stderr to both console and log file
        # exec > >(tee -a "$log_file") 2>&1
        # Redirect stdout and stderr, stripping color codes for the log file
        exec > >(tee >(sed -u 's/\x1B\[[0-9;]*[a-zA-Z]//g' >> "$log_file")) 2>&1
    fi
}
# @description Detect GPU and determine appropriate driver
# @noargs
detect_gpu_driver() {
    local gpu_info
    local gpu_vendor
    local gpu_driver

    # Get GPU information
    gpu_info=$(lspci -nn | grep -E "VGA|3D|Display")
    
    # Determine GPU vendor using a case statement
    case "$gpu_info" in
        *NVIDIA*)
            gpu_vendor="nvidia"
            gpu_driver="nvidia"
            ;;
        *AMD*)
            gpu_vendor="amd"
            gpu_driver="xf86-video-amdgpu"
            ;;
        *Intel*)
            gpu_vendor="intel"
            gpu_driver="xf86-video-intel"
            ;;
        *)
            gpu_vendor="unknown"
            gpu_driver="mesa"  # Generic driver
            ;;
    esac

    # Save GPU vendor and driver using set_option
    set_option "GPU_VENDOR" "$gpu_vendor"
    set_option "GPU_DRIVER" "$gpu_driver"

    # Print detected GPU information
    print_message INFO "Detected GPU Vendor: $gpu_vendor"
    print_message INFO "Selected GPU Driver: $gpu_driver"
}
# @description Validate password.
# @arg $1 string Password
# @return 0 on success, 1 on failure
validate_password() {
    local password="$1"
    local min_length=8
    local max_length=64
    local min_numbers=2  # Set the minimum number of numeric characters required
    local special_chars="!@#$%^&*<>-_=+?"
    local min_special=1

    if [[ ${#password} -lt $min_length || ${#password} -gt $max_length ]]; then
        print_message ERROR "Password must be between $min_length and $max_length characters."
        return 1
    fi

    if ! [[ "$password" =~ [A-Z] ]]; then
        print_message ERROR "Password must contain at least one uppercase letter."
        return 1
    fi

    if ! [[ "$password" =~ [a-z] ]]; then
        print_message ERROR "Password must contain at least one lowercase letter."
        return 1
    fi

    if ! [[ "$password" =~ [0-9] ]]; then
        print_message ERROR "Password must contain at least one digit."
        return 1
    fi

    # Check for special characters
    if ! [[ "$password" =~ [$special_chars] ]]; then
        print_message ERROR "Password must contain at least one special character from the set: $special_chars"
        return 1
    fi

    # Check for whitespace
    if [[ "$password" =~ [[:space:]] ]]; then
        print_message ERROR "Password must not contain any whitespace characters."
        return 1
    fi

    # Check for minimum number of numeric characters
    if [[ "$(echo "$password" | tr -cd '0-9' | wc -c)" -lt $min_numbers ]]; then
        print_message ERROR "Password must contain at least $min_numbers numeric characters."
        return 1
    fi
    # Check for minimum number of special characters
    if [[ "$(echo "$password" | tr -cd "$special_chars" | wc -c)" -lt $min_special ]]; then
        print_message ERROR "Password must contain at least $min_special special character(s) from the set: $special_chars"
        return 1
    fi

    return 0
}
# @description Validate configuration file.
# @arg $1 string Configuration file
# @return 0 on success, 1 on failure
validate_config() {
    local config_file="$1"
    local username password format_type subvolumes luks_password install_device
    local bios_type locale keymap hostname gpu_driver terminal shell editor desktop
    local errors=0

    # Load (source) the configuration file
    . "$config_file"

    # Validate username
    if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_-]{3,}$ ]]; then
        print_message ERROR "Invalid username. Must be at least 3 characters and can include letters, numbers, '-', '_'."
        errors=$((errors + 1))
    fi

    # Validate password
    if [[ "$PASSWORD" == "changeme" ]]; then
        print_message WARNING "Password is 'changeme'. Please provide a new password."
        errors=$((errors + 1))
    elif ! validate_password "$PASSWORD"; then
        errors=$((errors + 1))
    fi

    # Validate format type
    if [[ ! "$FORMAT_TYPE" =~ ^(btrfs|ext4)$ ]]; then
        print_message ERROR "Invalid format type. Must be 'btrfs', 'ext4'."
        errors=$((errors + 1))
    elif [[ "$FORMAT_TYPE" == "btrfs" ]]; then
        if [[ ! "$SUBVOLUMES" =~ ^(@|@home|@\.snapshots)$ ]]; then
            print_message ERROR "Invalid subvolumes for btrfs. Must include '@', '@home', '@.snapshots'."
            errors=$((errors + 1))
        fi
    fi

    # Validate LUKS password
    if [[ "$LUKS" == "true" && -z "$LUKS_PASSWORD" ]]; then
        print_message ERROR "LUKS format requires a LUKS password."
        errors=$((errors + 1))
    elif [[ "$LUKS" == "true" ]]; then
        if ! validate_password "$LUKS_PASSWORD"; then
            errors=$((errors + 1))
        fi
    fi

    # Validate install device
    if [[ -z "$INSTALL_DEVICE" ]]; then
        print_message ERROR "No install device specified. Must provide a device like /dev/* 'vda', 'sda', 'nvme', etc!."
        errors=$((errors + 1))
    fi

    # Set defaults for optional parameters
    BIOS_TYPE="${BIOS_TYPE:-hybrid}"
    LOCALE="${LOCALE:-en_US.UTF-8}"
    KEYMAP="${KEYMAP:-us}"
    HOSTNAME="${HOSTNAME:-arch}"
    GPU_DRIVER="${GPU_DRIVER:-mesa}"
    TERMINAL="${TERMINAL:-alacritty}"
    SHELL="${SHELL:-bash}"
    EDITOR="${EDITOR:-neovim}"
    DESKTOP_ENVIRONMENT="${DESKTOP_ENVIRONMENT:-none}"
    LUKS="${LUKS:-false}"
    HOME="${HOME:-false}"
    SWAP="${SWAP:-false}"

    # Print default values if they were set
    print_message DEBUG "Using default BIOS_TYPE: $BIOS_TYPE"
    print_message DEBUG "Using default LOCALE: $LOCALE"
    print_message DEBUG "Using default KEYMAP: $KEYMAP"
    print_message DEBUG "Using default HOSTNAME: $HOSTNAME"
    print_message DEBUG "Using default GPU_DRIVER: $GPU_DRIVER"
    print_message DEBUG "Using default TERMINAL: $TERMINAL"
    print_message DEBUG "Using default SHELL: $SHELL"
    print_message DEBUG "Using default EDITOR: $EDITOR"
    print_message DEBUG "Using default DESKTOP_ENVIRONMENT: $DESKTOP_ENVIRONMENT"

    # Return 0 if no errors, 1 if there are errors
    return $errors
}
# @description Encrypt password.
# @arg $1 string Password
# @return string Encrypted password
encrypt_password() {
    local password="$1"
    local encrypted_password

    # Ensure RSA environment is initialized
    [[ -z "$RSA_PUBLIC_KEY_PATH" ]] && init_rsa_env

    # Check if public key exists
    if [[ ! -f "$RSA_PUBLIC_KEY_PATH" ]]; then
        print_message ERROR "Public key not found at $RSA_PUBLIC_KEY_PATH"
        return 1
    fi

    # Encrypt the password using the public key
    encrypted_password=$(echo -n "$password" | openssl rsautl -encrypt -pubin -inkey "$RSA_PUBLIC_KEY_PATH" | base64) || {
        print_message ERROR "Password encryption failed"
        return 1
    }

    echo "$encrypted_password"
}
# @description Decrypt password.
# @arg $1 string Encrypted password
# @return string Decrypted password
decrypt_password() {
    local encrypted_password="$1"
    local decrypted_password
    local key_path

    # Ensure RSA environment is initialized
    [[ -z "$RSA_PRIVATE_KEY_PATH" ]] && init_rsa_env

    # Check for private key in different locations
    # Check if the key location is in the .env file of a previous
    # install, use it
    if [[ -f "$RSA_PRIVATE_KEY_PATH" ]]; then
        key_path="$RSA_PRIVATE_KEY_PATH"
    elif [[ -f "$HOME/.config/arch-install/private_key.pem" ]]; then
        key_path="$HOME/.config/arch-install/private_key.pem"
    else
        print_message ERROR "Private key not found"
        return 1
    fi

    # Validate key permissions
    if [[ "$(stat -c %a "$key_path")" != "600" ]]; then
        print_message WARNING "Incorrect permissions on private key. Fixing..."
        chmod 600 "$key_path" || {
            print_message ERROR "Failed to set correct permissions on private key"
            return 1
        }
    fi

    # Decrypt the password
    decrypted_password=$(echo "$encrypted_password" | base64 -d | openssl rsautl -decrypt -inkey "$key_path") || {
        print_message ERROR "Password decryption failed"
        return 1
    }

    echo "$decrypted_password"
}
# @description Generate RSA keys and initialize environment
# @noargs
generate_rsa_keys() {
    local commands=()
    
    # Ensure RSA environment is initialized
    [[ -z "$RSA_KEY_DIR" ]] && init_rsa_env
    
    check_openssl || return 1

    commands+=("mkdir -p $RSA_KEY_DIR")
    commands+=("chmod 700 $RSA_KEY_DIR")
    commands+=("openssl genpkey -algorithm RSA -out $RSA_PRIVATE_KEY_PATH -pkeyopt rsa_keygen_bits:2048")
    commands+=("chmod 600 $RSA_PRIVATE_KEY_PATH")
    commands+=("openssl rsa -pubout -in $RSA_PRIVATE_KEY_PATH -out $RSA_PUBLIC_KEY_PATH")
    commands+=("chmod 644 $RSA_PUBLIC_KEY_PATH")

    execute_process "Generating RSA keys" \
        --debug \
        --use-chroot \
        --error-message "Generating RSA keys failed" \
        --success-message "RSA keys generated and stored in $RSA_KEY_DIR" \
        "${commands[@]}"
}
# @description Create .env file with RSA configuration
create_env_file() {
    # Ensure RSA environment is initialized
    [[ -z "$RSA_KEY_DIR" ]] && init_rsa_env

    local user_env_dir="$HOME/.config/arch-install"
    local user_env_file="$user_env_dir/.env"
    local local_env_dir="/arch_install/config"
    local local_env_file="$local_env_dir/.env"

    # Check if the user's .env file exists
    if [[ -f "$user_env_file" ]]; then
        print_message INFO ".env file found at $user_env_file. Using existing file."
        # Source the existing file to update current environment
        source "$user_env_file"
        return 0
    fi

    # Create a local .env file if the user's .env file does not exist
    mkdir -p "$local_env_dir" || {
        print_message ERROR "Failed to create local environment directory"
        return 1
    }
    chmod 700 "$local_env_dir"

    cat <<EOF > "$local_env_file"
# RSA key configuration
RSA_KEY_DIR="$RSA_KEY_DIR"
RSA_PRIVATE_KEY_PATH="$RSA_PRIVATE_KEY_PATH"
RSA_PUBLIC_KEY_PATH="$RSA_PUBLIC_KEY_PATH"
EOF

    chmod 600 "$local_env_file" || {
        print_message ERROR "Failed to set permissions on .env file"
        return 1
    }
    
    print_message ACTION ".env file created locally at $local_env_file with RSA key paths."
    return 0
}
# @description Example usage of RSA encryption functions
# @noargs
usage() {
    # Initialize environment
    init_rsa_env
    
    # Generate keys if they don't exist
    if [[ ! -f "$RSA_PRIVATE_KEY_PATH" ]] || [[ ! -f "$RSA_PUBLIC_KEY_PATH" ]]; then
        generate_rsa_keys || {
            print_message ERROR "Failed to generate RSA keys"
            return 1
        }
    fi

    # Example encryption/decryption
    local encrypted decrypted
    encrypted=$(encrypt_password "my_secure_password") || return 1
    print_message INFO "Encrypted Password: $encrypted"

    decrypted=$(decrypt_password "$encrypted") || return 1
    print_message INFO "Decrypted Password: $decrypted"
}
