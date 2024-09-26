#!/bin/bash

HOOK_DIR="/etc/pacman.d/hooks"
HOOK_FILE="$HOOK_DIR/recovery_system.hook"

# Ensure the hook directory exists
sudo mkdir -p "$HOOK_DIR"

# Create the hook file
sudo tee "$HOOK_FILE" > /dev/null << EOL
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Updating master package list and config backups
When = PostTransaction
Exec = /path/to/recovery_system.sh update --git
EOL

echo "Pacman hook created at $HOOK_FILE"
