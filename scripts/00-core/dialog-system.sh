#!/bin/env bash
# Dialog System Script
# Author: ssnow
# Date: 2024
# Description: Advanced dialog system for user interactions

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

# Setup error handling
setup_error_handling() {
    trap 'error_handler $? $LINENO ${FUNCNAME[-1]:-main}' ERR
    trap 'exit_handler $?' EXIT
    trap 'cleanup_handler' SIGINT SIGTERM
}

# Initialize logging and error handling
init_system() {
    process_init "Dialog System"
    setup_error_handling
    ensure_log_directory
}

# Theme configuration
declare -A DIALOG_THEME=(
    [title_color]="cyan"
    [border_color]="blue"
    [text_color]="white"
    [button_color]="green"
    [button_text]="black"
)

# Initialize dialog with theme
init_dialog() {
    export DIALOGRC="/tmp/dialogrc"
    cat > "$DIALOGRC" << EOF
screen_color = (${DIALOG_THEME[text_color]},black,off)
title_color = (${DIALOG_THEME[title_color]},black,off)
border_color = (${DIALOG_THEME[border_color]},black,off)
button_active_color = (${DIALOG_THEME[button_color]},${DIALOG_THEME[button_text]},off)
button_inactive_color = (white,black,off)
EOF
}

# Dialog response handler with error integration
handle_dialog_response() {
    local response=$?
    case $response in
        0) return 0 ;;
        1) print_message WARNING "User canceled dialog"; return 1 ;;
        255) 
            print_message ERROR "Dialog terminated abnormally"
            handle_critical_error "Dialog system failure"
            return 1 
            ;;
    esac
}

# Enhanced yes/no dialog
ask_yes_no() {
    local title="$1"
    local question="$2"
    local default_answer="${3:-yes}"

    dialog --clear \
           --title "$title" \
           --yesno "$question" 8 60 \
           $([ "$default_answer" = "no" ] && echo "--defaultno")
    
    handle_dialog_response
    local response=$?
    clear
    return $response
}

# Function for single selection from list
select_from_list() {
    local title="$1"
    shift
    local options=("$@")
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --menu "Select an option:" 15 60 8 \
           "${options[@]}" 2>"$temp_file"
    
    local result=$?
    local selection=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$selection"
    return $result
}

# Function for multiple selection
select_multiple() {
    local title="$1"
    shift
    local options=("$@")
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --checklist "Select options:" 15 60 8 \
           "${options[@]}" 2>"$temp_file"
    
    local result=$?
    local selections=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$selections"
    return $result
}

# Function for text input
get_text_input() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --inputbox "$prompt" 8 60 "$default" 2>"$temp_file"
    
    local result=$?
    local input=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$input"
    return $result
}

# Function for password input
get_password() {
    local title="$1"
    local prompt="$2"
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --passwordbox "$prompt" 8 60 2>"$temp_file"
    
    local result=$?
    local password=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$password"
    return $result
}

# Function for fzf-based selection
fzf_select() {
    local title="$1"
    shift
    local options=("$@")
    
    printf '%s\n' "${options[@]}" | fzf --prompt="$title > " \
                                      --height=40% \
                                      --border=rounded \
                                      --margin=1 \
                                      --padding=1
}

# Progress bar function
show_progress() {
    local title="$1"
    local total="$2"
    local current="$3"
    local message="$4"
    
    echo "$current" | dialog --title "$title" \
                            --gauge "$message" 8 60 0
}

# Example usage function
example_usage() {
    init_dialog

    if ask_yes_no "Configuration" "Do you want to proceed with the setup?"; then
        local name=$(get_text_input "User Info" "Enter your name:")
        local password=$(get_password "Security" "Enter your password:")
        
        local desktop_options=(
            "1" "GNOME" 
            "2" "KDE" 
            "3" "XFCE" 
            "4" "i3"
        )
        
        local desktop=$(select_from_list "Desktop Selection" "${desktop_options[@]}")
        
        local package_options=(
            "1" "Development Tools" "off"
            "2" "Office Suite" "off"
            "3" "Multimedia" "off"
            "4" "Gaming" "off"
        )
        
        local packages=$(select_multiple "Package Selection" "${package_options[@]}")
        
        clear
        echo "Name: $name"
        echo "Desktop: $desktop"
        echo "Selected packages: $packages"
    fi
}

# Main function
main() {
    init_system

    if ! command -v dialog >/dev/null; then
        print_message ERROR "dialog is not installed. Installing..."
        if ! pacman -S --noconfirm dialog; then
            handle_critical_error "Failed to install dialog"
            return 1
        fi
    fi
    
    if ! command -v fzf >/dev/null; then
        print_message ERROR "fzf is not installed. Installing..."
        if ! pacman -S --noconfirm fzf; then
            print_message WARNING "fzf installation failed, continuing without fzf support"
        fi
    fi

    example_usage
    process_end $?
}

# Run the script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi