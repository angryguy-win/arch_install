#!/bin/bash
# Post-setup Script
# Author: ssnow
# Date: 2024
# Description: Post-setup script for Arch Linux installation

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi

main() {
    process_init "Post-setup"
    print_message INFO "Starting post-setup process"

    # Add your post-setup logic here

    print_message OK "Post-setup process completed successfully"
    process_end $?
}

main "$@"
exit $?