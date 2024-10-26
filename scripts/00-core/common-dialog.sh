#!/bin/env bash

# Core initialization and imports
source "$(dirname "$0")/dialog-state.sh"
source "$(dirname "$0")/dialog-backup.sh"

# Privilege levels and operation tracking
declare -A PRIVILEGE_LEVELS=(
    [NONE]=0
    [USER]=1
    [ROOT]=2
    [CHROOT]=3
)

declare -A OPERATION_STATUS=(
    [SUCCESS]=0
    [WARNING]=1
    [ERROR]=2
    [CRITICAL]=3
)

# Installation stages mapping
declare -A INSTALL_STAGES=(
    [PRE_INSTALL]=1
    [DRIVE_SETUP]=2
    [BASE_INSTALL]=3
    [POST_CONFIG]=4
    [DESKTOP]=5
    [FINAL]=6
    [POST_SETUP]=7
)

# Core execution function
execute_dialog_operation() {
    local operation_name="$1"
    shift
    local privilege_level="${PRIVILEGE_LEVELS[NONE]}"
    local debug=${DEBUG:-false}
    local critical=false
    local error_message="Operation failed"
    local success_message="Operation completed"
    local operations=()

    while [[ "$1" == --* ]]; do
        case "$1" in
            --privilege) 
                privilege_level="${PRIVILEGE_LEVELS[${2^^}]}"
                shift 2 
                ;;
            --debug) debug=true; shift ;;
            --critical) critical=true; shift ;;
            --error-message) error_message="$2"; shift 2 ;;
            --success-message) success_message="$2"; shift 2 ;;
            *) print_message ERROR "Unknown option: $1"; return 1 ;;
        esac
    done

    if ! verify_privileges "$privilege_level"; then
        handle_operation_error "$operation_name" "privilege_check" "Insufficient privileges" "$critical"
        return 1
    fi

    operations=("$@")
    log "OPERATION" "Starting: $operation_name (Privilege: ${privilege_level})"
    
    for op in "${operations[@]}"; do
        if [[ "$debug" == true ]]; then
            print_message DEBUG "Executing: $op"
        fi

        execute_privileged_operation "$op" "$privilege_level" "$critical"
        local status=$?
        
        if [[ $status -ne 0 ]]; then
            handle_operation_error "$operation_name" "$op" "$error_message" "$critical"
            [[ "$critical" == true ]] && return 1
        fi
    done

    print_message OK "$success_message"
    return 0
}

# Core privilege handling
verify_privileges() {
    local required_level="$1"
    
    case "$required_level" in
        ${PRIVILEGE_LEVELS[ROOT]})
            if [[ $EUID -ne 0 ]]; then
                print_message ERROR "Root privileges required"
                return 1
            fi
            ;;
        ${PRIVILEGE_LEVELS[CHROOT]})
            if [[ ! -d /mnt ]]; then
                print_message ERROR "Chroot environment not ready"
                return 1
            fi
            ;;
    esac
    return 0
}

execute_privileged_operation() {
    local operation="$1"
    local privilege_level="$2"
    local critical="$3"
    
    case "$privilege_level" in
        ${PRIVILEGE_LEVELS[ROOT]})
            sudo bash -c "$operation"
            ;;
        ${PRIVILEGE_LEVELS[CHROOT]})
            arch-chroot /mnt /bin/bash -c "$operation"
            ;;
        *)
            eval "$operation"
            ;;
    esac
}

# Error handling
handle_operation_error() {
    local operation_name="$1"
    local operation="$2"
    local error_message="$3"
    local critical="$4"

    print_message ERROR "$error_message: $operation"
    log "ERROR" "Failed operation: $operation_name - $operation"

    if [[ "$critical" == true ]]; then
        handle_critical_error "Critical operation failed: $operation_name"
        return 1
    fi
    return 0
}
