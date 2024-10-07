#!/bin/sh
# Run Checks Script
# Author: ssnow
# Date: 2024
# Description: Run checks script for Arch Linux installation

set -e
trap 'exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

# shellcheck source=../../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi


ask_passwords() {
    local passwords=""
    print_message INFO "Setting up the necessary passwords"

    # Build the passwords string
    [ "$PASSWORD" = "changeme" ] && passwords+="PASSWORD:$USERNAME "
    [ "$LUKS" = "true" ] && passwords+="LUKS_PASSWORD:LUKS "
    [ "$ROOT_SAME_AS_USER_PASSWORD" != "true" ] && [ "$ROOT_PASSWORD" = "changeme" ] && passwords+="ROOT_PASSWORD:root "
    [ -n "$WIFI_INTERFACE" ] && [ "$WIFI_KEY" = "ask" ] && passwords+="WIFI_KEY:WIFI "

    # Process each password
    for password_info in $passwords; do
        IFS=':' read -r var_name context <<< "$password_info"
        ask_password "$context" "$var_name"
    done
}

check_and_setup_internet() {
    print_message INFO "Checking internet connection..."
    if ping -c 1 archlinux.org > /dev/null 2>&1; then
        print_message OK "Internet connection is available"
        return 0
    else
        print_message WARNING "No internet connection. Attempting to set up WiFi..."
        setup_wifi
        return 1
    fi
}

setup_wifi() {
    local interfaces
    print_message INFO "Setting up WiFi connection..."

    # Get WiFi interface
    interfaces=$(iwctl device list | grep station | awk '{print $2}')
    if [ -z "$interfaces" ]; then
        print_message ERROR "No WiFi interfaces found."
        return 1
    fi

    # If there's only one interface, use it. Otherwise, ask the user to choose.
    if [ "$(printf '%s\n' "$interfaces" | wc -l)" -eq 1 ]; then
        WIFI_INTERFACE=$interfaces
    else
        print_message INFO "Multiple WiFi interfaces found. Please choose one:"
        i=1
        printf '%s\n' "$interfaces" | while IFS= read -r interface; do
            printf "%d) %s\n" "$i" "$interface"
            i=$((i+1))
        done
        while true; do
            printf "Enter selection: "
            read -r selection
            case $selection in
                [1-9]*)
                    WIFI_INTERFACE=$(printf '%s\n' "$interfaces" | sed -n "${selection}p")
                    [ -n "$WIFI_INTERFACE" ] && break
                    ;;
            esac
            printf "Invalid selection. Please try again.\n"
        done
    fi

    # Get SSID
    print_message INFO "Scanning for networks..."
    iwctl station "$WIFI_INTERFACE" scan
    sleep 2
    iwctl station "$WIFI_INTERFACE" get-networks

    printf "Enter the SSID of the network you want to connect to: "
    read -r WIFI_ESSID

    # Get password
    stty -echo
    printf "Enter the WiFi password: "
    read -r WIFI_KEY
    stty echo
    printf "\n"

    # Attempt to connect
    print_message INFO "Attempting to connect to %s..." "$WIFI_ESSID"
    if iwctl --passphrase "$WIFI_KEY" station "$WIFI_INTERFACE" connect "$WIFI_ESSID"; then
        print_message OK "Successfully connected to %s" "$WIFI_ESSID"
        sleep 5  # Give some time for the connection to stabilize

        # Verify internet connection
        if ping -c 1 archlinux.org > /dev/null 2>&1; then
            print_message OK "Internet connection established"
            # Save the WiFi settings to the configuration
            set_option "WIFI_INTERFACE" "$WIFI_INTERFACE"
            set_option "WIFI_ESSID" "$WIFI_ESSID"
            set_option "WIFI_KEY" "$WIFI_KEY"
            return 0
        else
            print_message ERROR "Connected to WiFi, but still no internet access"
            return 1
        fi
    else
        print_message ERROR "Failed to connect to %s" "$WIFI_ESSID"
        return 1
    fi
}
run_checks() {
    print_message INFO "Running checks..."
    show_system_info
}

main() {
    process_init "Run Checks"
    print_message INFO "Starting run checks process"

    run_checks
    #facts_commons
    #ask_for_installation_info
    ask_passwords
    check_and_setup_internet
    #ask_for_password

    print_message OK "Run checks process completed successfully"
    process_end $?
}

main "$@"