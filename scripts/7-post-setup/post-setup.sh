#!/bin/bash
# Post Setup Script
# Author: ssnow
# Date: 2024
# Description: Post setup script for Arch Linux installation

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
    process_init "Post Setup"
    print_message INFO "Starting post setup process"


    print_message OK "Post setup process completed successfully"
    process_end $?
}

main "$@"
exit $?