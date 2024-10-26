#!/bin/env bash

CONFIG_REPO="/mnt/var/lib/arch-install/config-versions"

version_config() {
    local config_file="$1"
    local version_tag="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Create version directory
    local version_dir="$CONFIG_REPO/$version_tag"
    mkdir -p "$version_dir"
    
    # Copy config with metadata
    cp "$config_file" "$version_dir/${timestamp}_${config_file##*/}"
    
    # Create version metadata
    cat > "$version_dir/metadata.toml" << EOF
timestamp = "$timestamp"
version = "$version_tag"
config_file = "${config_file##*/}"
stage = "${DIALOG_STATE[current_step]}"
EOF
    
    # Maintain version history
    echo "$timestamp:$version_tag:$config_file" >> "$CONFIG_REPO/version_history.log"
}

restore_config_version() {
    local version_tag="$1"
    local target_dir="$CONFIG_REPO/$version_tag"
    
    if [[ -d "$target_dir" ]]; then
        local latest_config=$(ls -t "$target_dir" | grep -v metadata.toml | head -1)
        cp "$target_dir/$latest_config" "${latest_config#*_}"
        return 0
    fi
    return 1
}
