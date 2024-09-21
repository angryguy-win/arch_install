#!/bin/bash
# None Script
# Author: ssnow
# Date: 2024
# Description: None script for Arch Linux installation

set -e
trap 'exit 1' INT TERM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

# shellcheck source=../../lib/lib.sh
if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

main() {
    process_init "None"
    print_message INFO "Starting none process"


    print_message OK "None process completed successfully"
    process_end $?
}

main "$@"
exit $?