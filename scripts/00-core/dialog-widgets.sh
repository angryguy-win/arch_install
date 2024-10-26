#!/bin/env bash
# Dialog Widgets Script
# Author: ssnow
# Date: 2024
# Description: Dialog widgets


# Custom file browser widget
file_browser() {
    local title="$1"
    local start_dir="${2:-$PWD}"
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --fselect "$start_dir/" 10 60 2>"$temp_file"
    
    local result=$?
    local selection=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$selection"
    return $result
}

# Custom calendar widget
calendar_select() {
    local title="$1"
    local temp_file=$(mktemp)
    
    dialog --title "$title" \
           --calendar "Select a date:" 0 0 2>"$temp_file"
    
    local result=$?
    local selection=$(cat "$temp_file")
    rm "$temp_file"
    
    echo "$selection"
    return $result
}

# Custom multi-column selection
table_select() {
    local title="$1"
    shift
    local headers=("$1")
    shift
    local data=("$@")
    
    dialog --title "$title" \
           --column-separator "|" \
           --menu "Select an item:" 15 60 8 \
           "${data[@]}" 2>/tmp/selection
}