#!/bin/bash
# Template Script
# Author: ssnow
# Date: 2024
# Description: Generic template for installation scripts

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

export DRY_RUN="${DRY_RUN:-false}"
print_message INFO "DRY_RUN in $(basename "$0") is set to: $DRY_RUN"

setup_error_handling

# Function template
function_name() {
    # Initialize the function
    local commands
    local messages
    local var1
    local var2
    local var3
    # Set the variables
    var1="$1"
    var2="$2"
    var3="$3"
    # Set the commands
    commands=(
        "command1 $var1"
        "command2 $var2"
        "command3 $var3"
    )
    # Set the messages
    messages=(
        "Executing command 1"
        "Executing command 2"
        "Executing command 3"
    )
    # Execute the function
    execute_process "Function Name" \
        --debug \
        --error-message "- Function failed" \
        --success-message "- Function completed successfully" \
        "${commands[@]}" "${messages[@]}"
        # --use-chroot # Uncomment to use chroot optional
}

# Another function template
another_function() {
    local commands
    local messages

    commands=(
        "command4"
        "command5"
    )

    messages=(
        "Executing command 4"
        "Executing command 5"
    )

    execute_process "Another Function" \
        --debug \
        --error-message "- Another function failed" \
        --success-message "- Another function completed successfully" \
        "${commands[@]}" "${messages[@]}"
        # --use-chroot # Uncomment to use chroot optional
}

main() {
    # Initialize the script
    process_init "Script Name"
    # Show the logo
    show_logo "Script Name"
    # Print a message to the console
    print_message INFO "Starting script execution"
    # Load configuration variables from the key=value arch_config.cfg file
    local vars=(key_name1 key_name2 key_name3)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }

    # Execute functions
    function_name key_name1 key_name2 key_name3 || { print_message ERROR "Function name failed"; return 1; }
    another_function || { print_message ERROR "Another function failed"; return 1; }

    # Add more functions as needed

    # Print a message to the console#   
    print_message OK "Script execution completed successfully"
    # End the script
    process_end $?
}
# Run the main function
main "$@"
# Exit the script with the return code of the main function
exit $?