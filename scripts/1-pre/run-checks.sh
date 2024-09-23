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

run_checks() {

    show_system_info
    check_internet_connection
    check_disk_space
}

main() {
    process_init "Run Checks"
    print_message INFO "Starting run checks process"

    run_checks
    ask_for_password

    print_message OK "Run checks process completed successfully"
    process_end $?
}

main "$@"