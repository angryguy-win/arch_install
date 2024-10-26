#!/bin/env bash

# State persistence location
PERSIST_DIR="/mnt/var/lib/arch-install"
PERSIST_FILE="$PERSIST_DIR/install_state"

# Save state before reboot
save_persistent_state() {
    execute_process "Save Persistent State" \
        --debug \
        --critical \
        "mkdir -p $PERSIST_DIR" \
        "declare -p DIALOG_STATE > $PERSIST_FILE" \
        "declare -p STATE_DATA >> $PERSIST_FILE" \
        "chmod 600 $PERSIST_FILE"
}

# Restore state after reboot
restore_persistent_state() {
    if [[ -f "$PERSIST_FILE" ]]; then
        source "$PERSIST_FILE"
        print_message INFO "Restored installation state from: $PERSIST_FILE"
        return 0
    fi
    return 1
}
