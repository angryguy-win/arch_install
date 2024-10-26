#!/bin/env bash

# Notification types
declare -A NOTIFY_TYPES=(
    [SUCCESS]="✓"
    [WARNING]="⚠"
    [ERROR]="✗"
    [INFO]="ℹ"
)

notify_backup_status() {
    local status="$1"
    local message="$2"
    local stage="$3"
    
    case "$status" in
        SUCCESS)
            print_message OK "${NOTIFY_TYPES[SUCCESS]} Backup complete: $stage - $message"
            ;;
        WARNING)
            print_message WARNING "${NOTIFY_TYPES[WARNING]} Backup warning: $stage - $message"
            ;;
        ERROR)
            print_message ERROR "${NOTIFY_TYPES[ERROR]} Backup failed: $stage - $message"
            handle_critical_error "$message"
            ;;
    esac
    
    # Log notification
    log "NOTIFY" "$status: $stage - $message"
}
