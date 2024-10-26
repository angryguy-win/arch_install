#!/bin/env bash

# Enhanced backup logging
backup_with_logging() {
    local backup_type="$1"
    local stage_name="$2"
    
    log "BACKUP" "Starting backup for $backup_type at stage $stage_name"
    print_message INFO "Creating backup point"
    
    # Create backup directory structure
    local backup_path="${BACKUP_DIR}/${stage_name}/${backup_type}"
    mkdir -p "$backup_path"
    
    # Perform backup with detailed logging
    {
        backup_config 2>&1
        backup_fstab 2>&1
        save_persistent_state 2>&1
    } | while IFS= read -r line; do
        log "BACKUP" "$line"
    done
    
    # Log backup completion status
    if [ $? -eq 0 ]; then
        print_message OK "Backup completed successfully"
        log "BACKUP" "Backup completed: $backup_path"
    else
        print_message ERROR "Backup failed"
        log "BACKUP" "Backup failed: $backup_path"
        return 1
    fi
}
