#!/bin/env bash

# Backup configuration
declare -A BACKUP_TYPES=(
    [STATE]="dialog_state"
    [CONFIG]="system_config"
    [PROGRESS]="install_progress"
    [FSTAB]="fstab"
    [CRITICAL]="critical_point"
)

BACKUP_DIR="/mnt/var/lib/arch-install/backups"
MAX_BACKUPS=3

backup_installation_state() {
    local backup_type="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${BACKUP_TYPES[$backup_type]}_${timestamp}"

    execute_process "Backup $backup_type" \
        --debug \
        --error-message "Failed to backup $backup_type" \
        --critical \
        "mkdir -p $BACKUP_DIR" \
        "declare -p DIALOG_STATE > $backup_file" \
        "declare -p STATE_DATA >> $backup_file" \
        "chmod 600 $backup_file"

    # Rotate old backups (similar to your existing backup_fstab function)
    cleanup_old_backups "$backup_type"
}

backup_installation_point() {
    local backup_type="$1"
    local stage_name="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    execute_process "Backup $backup_type" \
        --debug \
        --critical \
        --error-message "Failed to create backup point" \
        "backup_config" \
        "backup_fstab" \
        "save_persistent_state"

    # Verify backup integrity
    verify_backup_integrity "$backup_type" "$timestamp"
}

# Validate restored state
validate_restored_state() {
    local required_vars=(
        "DIALOG_STATE[current_step]"
        "DIALOG_STATE[total_steps]"
        "STATE_DATA[drive_type]"
        "STATE_DATA[desktop_env]"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            handle_critical_error "Invalid backup: Missing $var"
            return 1
        fi
    done
    return 0
}

# Recovery menu
show_recovery_menu() {
    local options=(
        "1" "Resume from last checkpoint" 
        "2" "Start fresh installation" 
        "3" "View installation logs" 
        "4" "Emergency shell"
    )
    
    local choice=$(select_from_list "Recovery Options" "${options[@]}")
    case $choice in
        1) recover_installation ;;
        2) confirm_fresh_install ;;
        3) view_logs ;;
        4) emergency_shell ;;
    esac
}