#!/bin/bash

MASTER_LIST="/etc/recovery_system/master_package_list.txt"
CONFIG_BACKUP="/etc/recovery_system/config_backups"
LOG_FILE="/var/log/recovery_system.log"
GIT_REPO="/etc/recovery_system/git_backup"
RSYNC_DEST="/etc/recovery_system/rsync_backup"

# Color definitions
declare -A COLORS=(
    [RESET]="\033[0m"
    [RED]="\033[0;31m"
    [GREEN]="\033[0;32m"
    [YELLOW]="\033[0;33m"
    [BLUE]="\033[0;34m"
    [MAGENTA]="\033[0;35m"
    [CYAN]="\033[0;36m"
    [WHITE]="\033[0;37m"
    [BOLD]="\033[1m"
)

# Logging function
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp [$level] $message" >> "$LOG_FILE"
}

# Print formatted messages
print_message() {
    local type="${1:-INFO}"
    local message="${2:-No message provided}"
    local prefix_color=""
    local prefix="[$type]"

    case "$type" in
        INFO) prefix_color="${COLORS[BLUE]}" ;;
        SUCCESS) prefix_color="${COLORS[GREEN]}" ;;
        WARNING) prefix_color="${COLORS[YELLOW]}" ;;
        ERROR) prefix_color="${COLORS[RED]}" ;;
    esac

    printf "%b%s%b %s\n" "$prefix_color" "$prefix" "${COLORS[RESET]}" "$message"
    log "$type" "$message"
}

update_master_list() {
    print_message "INFO" "Updating master package list..."
    if pacman -Qqen > "$MASTER_LIST.official" && \
       pacman -Qqem > "$MASTER_LIST.aur" && \
       cat "$MASTER_LIST.official" "$MASTER_LIST.aur" | sort -u > "$MASTER_LIST"; then
        print_message "SUCCESS" "Master package list updated at $(date)"
    else
        print_message "ERROR" "Failed to update master package list"
    fi
}

backup_config_files() {
    local configs=(
        "/etc/fstab"
        "/etc/pacman.conf"
        "/etc/mkinitcpio.conf"
        "/etc/recovery_system/master_package_list.toml"
        "/etc/recovery_system/config_backups"
        "/etc/recovery_system/git_backup"
        "/etc/recovery_system/rsync_backup"
        "/etc/recovery_system/hooks.sh"
        "/etc/recovery_system/recovery_system.sh"
        "/etc/recovery_system/lib-recovery.sh"
        "/etc/recovery_system/package_manager.sh"
        "/etc/recovery_system/README.md"
        "/etc/recovery_system/LICENSE"
        "/etc/recovery_system/CHANGELOG.md"
        "/etc/recovery_system/TODO.md"

        # Add more config files as needed
    )
    
    local backup_dir="$CONFIG_BACKUP/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    for config in "${configs[@]}"; do
        if cp "$config" "$backup_dir/" 2>/dev/null; then
            print_message "INFO" "Backed up: $config"
        else
            print_message "WARNING" "Failed to backup: $config"
        fi
    done
    
    print_message "SUCCESS" "Configuration files backed up to $backup_dir"
}

reinstall_from_master_list() {
    if [ -f "$MASTER_LIST" ]; then
        print_message "WARNING" "This will reinstall all packages from the master list."
        read -p "Are you sure you want to continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message "INFO" "Reinstalling packages from master list..."
            if sudo pacman -S --needed - < "$MASTER_LIST"; then
                print_message "SUCCESS" "All packages reinstalled successfully"
            else
                print_message "ERROR" "Failed to reinstall some packages"
            fi
        else
            print_message "INFO" "Reinstallation cancelled"
        fi
    else
        print_message "ERROR" "Master package list not found at $MASTER_LIST"
    fi
}

compare_with_master_list() {
    if [ -f "$MASTER_LIST" ]; then
        print_message "INFO" "Comparing current packages with master list..."
        print_message "INFO" "Packages in master list but not currently installed:"
        comm -23 <(sort "$MASTER_LIST") <(pacman -Qqe | sort) | sed 's/^/  /'
    else
        print_message "ERROR" "Master package list not found at $MASTER_LIST"
    fi
}

backup_with_git() {
    if ! command -v git &> /dev/null; then
        print_message "ERROR" "Git is not installed. Please install git to use this feature."
        return 1
    fi

    if [ ! -d "$GIT_REPO" ]; then
        print_message "INFO" "Initializing Git repository for backups..."
        git init "$GIT_REPO"
    fi

    cp "$MASTER_LIST" "$GIT_REPO/"
    cp -r "$CONFIG_BACKUP" "$GIT_REPO/"

    cd "$GIT_REPO"
    git add .
    git commit -m "Backup $(date +%Y-%m-%d_%H-%M-%S)"

    print_message "SUCCESS" "Backup saved with Git at $GIT_REPO"
}

backup_with_rsync() {
    if ! command -v rsync &> /dev/null; then
        print_message "ERROR" "rsync is not installed. Please install rsync to use this feature."
        return 1
    fi

    mkdir -p "$RSYNC_DEST"

    rsync -av --delete "$MASTER_LIST" "$CONFIG_BACKUP" "$RSYNC_DEST/"

    print_message "SUCCESS" "Backup saved with rsync at $RSYNC_DEST"
}

restore_from_git() {
    if [ ! -d "$GIT_REPO" ]; then
        print_message "ERROR" "Git repository not found at $GIT_REPO"
        return 1
    fi

    cd "$GIT_REPO"
    git log --oneline
    read -p "Enter the commit hash to restore from: " commit_hash

    if git show "$commit_hash" &> /dev/null; then
        git checkout "$commit_hash" -- .
        cp "$GIT_REPO/master_package_list.txt" "$MASTER_LIST"
        cp -r "$GIT_REPO/config_backups" "$CONFIG_BACKUP"
        print_message "SUCCESS" "Restored from Git commit $commit_hash"
    else
        print_message "ERROR" "Invalid commit hash"
    fi
}

restore_from_rsync() {
    if [ ! -d "$RSYNC_DEST" ]; then
        print_message "ERROR" "rsync backup not found at $RSYNC_DEST"
        return 1
    fi

    cp "$RSYNC_DEST/master_package_list.txt" "$MASTER_LIST"
    cp -r "$RSYNC_DEST/config_backups" "$CONFIG_BACKUP"
    print_message "SUCCESS" "Restored from rsync backup"
}