#!/bin/env bash
# Dialog State Script
# Author: ssnow
# Date: 2024
# Description: Dialog state management


# Dialog state management
declare -A DIALOG_STATE=(
    [current_step]=0
    [total_steps]=0
    [last_input]=""
    [can_go_back]=true
)

# State management functions
init_dialog_flow() {
    local total_steps="$1"
    DIALOG_STATE[total_steps]="$total_steps"
    DIALOG_STATE[current_step]=1
}

advance_dialog() {
    DIALOG_STATE[current_step]=$((DIALOG_STATE[current_step] + 1))
    show_progress "Progress" "${DIALOG_STATE[total_steps]}" "${DIALOG_STATE[current_step]}" "Step ${DIALOG_STATE[current_step]} of ${DIALOG_STATE[total_steps]}"
}

go_back_dialog() {
    if [[ ${DIALOG_STATE[can_go_back]} == true ]]; then
        DIALOG_STATE[current_step]=$((DIALOG_STATE[current_step] - 1))
        return 0
    fi
    return 1
}