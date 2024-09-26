#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-recovery.sh"

show_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Recovery System Management

Commands:
  update              Update master package list and backup config files
  reinstall           Reinstall packages from the master list
  compare             Compare current packages with the master list
  restore             Restore from a previous backup
  help                Show this help message

Options:
    --force             Force the operation (applicable to update and reinstall)
    --dry-run           Perform a dry run without making changes
    --verbose           Enable verbose output
    --git               Use Git for backups (default)
    --rsync             Use rsync for backups
    --from-git          Restore from Git backup (use with restore command)
    --from-rsync        Restore from rsync backup (use with restore command)

Examples:
  $(basename "$0") update --git
  $(basename "$0") reinstall --force
  $(basename "$0") compare --verbose
  $(basename "$0") restore --from-git
  $(basename "$0") help

For more information, please refer to the script documentation.
EOF
}

parse_args() {
    COMMAND=""
    FORCE=false
    DRY_RUN=false
    VERBOSE=false
    USE_GIT=true
    USE_RSYNC=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            update|reinstall|compare|restore|help)
                COMMAND="$1"
                ;;
            --force)
                FORCE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --git)
                USE_GIT=true
                USE_RSYNC=false
                ;;
            --rsync)
                USE_GIT=false
                USE_RSYNC=true
                ;;
            --from-git)
                RESTORE_FROM_GIT=true
                ;;
            --from-rsync)
                RESTORE_FROM_RSYNC=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_message "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$COMMAND" ]]; then
        print_message "ERROR" "No command specified"
        show_help
        exit 1
    fi
}

execute_command() {
    case "$COMMAND" in
        update)
            [[ "$VERBOSE" == true ]] && print_message "INFO" "Updating master list and backing up configs"
            [[ "$DRY_RUN" == true ]] && print_message "DRY-RUN" "Would update master list and backup configs"
            [[ "$DRY_RUN" == false ]] && update_master_list && backup_config_files
            ;;
        reinstall)
            [[ "$VERBOSE" == true ]] && print_message "INFO" "Reinstalling packages from master list"
            [[ "$DRY_RUN" == true ]] && print_message "DRY-RUN" "Would reinstall packages from master list"
            [[ "$DRY_RUN" == false ]] && reinstall_from_master_list
            ;;
        compare)
            [[ "$VERBOSE" == true ]] && print_message "INFO" "Comparing current packages with master list"
            compare_with_master_list
            ;;
        restore)
            if [ "$RESTORE_FROM_GIT" = true ]; then
                restore_from_git
            elif [ "$RESTORE_FROM_RSYNC" = true ]; then
                restore_from_rsync
            else
                print_message "ERROR" "Please specify --from-git or --from-rsync when using the restore command"
                exit 1
            fi
            ;;
        help)
            show_help
            ;;
    esac
}

main() {
    parse_args "$@"
    execute_command
}

main "$@"
