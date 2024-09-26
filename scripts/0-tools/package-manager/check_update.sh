#!/bin/bash
# @description Package update checker and update list manager
# @version $SCRIPT_VERSION
# @author ssno
# @date 2024-07-29
# @license MIT

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$SCRIPT_DIR/lib_tools.sh"

if [ -f "$LIB_PATH" ]; then
    source "$LIB_PATH"
else
    echo "Error: Cannot find lib_tools.sh at $LIB_PATH" >&2
    exit 1
fi

# Set default values
VERBOSE=${VERBOSE:-false}
LOG_FILE=${LOG_FILE:-"$SCRIPT_DIR/check_update.log"}
UPDATE_LIST_FILE=${UPDATE_LIST_FILE:-"$SCRIPT_DIR/update_list.toml"}
export VERBOSE="$VERBOSE"

show_help() {
    echo "Usage: $0 [options] [package1] [package2] ..."
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -s, --system   Check for system-wide updates"
    echo "  -l, --log      Log output to file"
    echo "  -u, --update   Update packages if available"
    echo "  -f, --file     Specify a custom update list file (default: update_list.toml)"
    echo "  -c, --create   Create a new update list file"
    echo "  -a, --add      Add packages to the update list"
    echo "  -r, --remove   Remove packages from the update list"
    echo "If no packages are specified, only system-wide updates will be checked."
}

check_and_update_system() {
    print_message "INFO" "Checking for system updates..."
    if ! sudo pacman -Sy > /dev/null 2>&1; then
        print_message "WARNING" "Failed to update package database. Unable to check for updates."
        return 1
    fi
    print_message "INFO" "Package database updated successfully."
    
    local updates=$(pacman -Qu)
    local update_count=$(echo "$updates" | grep -v "^$" | wc -l)
    
    if [ "$update_count" -eq 0 ]; then
        print_message "INFO" "Your system is up to date."
    else
        print_message "INFO" "There are $update_count package(s) that can be upgraded:"
        echo "$updates"
        
        if [ "$AUTO_UPDATE" = true ]; then
            print_message "INFO" "Updating packages..."
            if sudo pacman -Syu --noconfirm; then
                print_message "SUCCESS" "Packages updated successfully."
            else
                print_message "ERROR" "Failed to update packages."
                return 1
            fi
        else
            read -p "Do you want to update these packages? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_message "INFO" "Updating packages..."
                if sudo pacman -Syu --noconfirm; then
                    print_message "SUCCESS" "Packages updated successfully."
                else
                    print_message "ERROR" "Failed to update packages."
                    return 1
                fi
            else
                print_message "INFO" "Update skipped."
            fi
        fi
    fi
}

check_and_update_package() {
    local package="$1"
    local local_version remote_version

    print_message "INFO" "Checking package: $package"

    local_version=$(pacman -Q "$package" 2>/dev/null | awk '{print $2}')
    if [ -z "$local_version" ]; then
        print_message "INFO" "Package $package is not installed."
        return 1
    fi

    remote_version=$(pacman -Si "$package" 2>/dev/null | grep 'Version' | awk '{print $3}')
    if [ -z "$remote_version" ]; then
        print_message "INFO" "Package $package is not available in the repositories."
        return 1
    fi

    print_message "INFO" "Package $package: Local version $local_version, Remote version $remote_version"

    if [ "$local_version" != "$remote_version" ]; then
        print_message "INFO" "Update available for package $package: $local_version -> $remote_version"
        
        if [ "$AUTO_UPDATE" = true ]; then
            print_message "INFO" "Updating package $package..."
            if sudo pacman -S --noconfirm "$package"; then
                print_message "SUCCESS" "Package $package updated successfully."
            else
                print_message "ERROR" "Failed to update package $package."
                return 1
            fi
        else
            read -p "Do you want to update this package? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_message "INFO" "Updating package $package..."
                if sudo pacman -S --noconfirm "$package"; then
                    print_message "SUCCESS" "Package $package updated successfully."
                else
                    print_message "ERROR" "Failed to update package $package."
                    return 1
                fi
            else
                print_message "INFO" "Update skipped for package $package."
            fi
        fi
    else
        print_message "INFO" "Package $package is up-to-date."
    fi
}

parse_update_list() {
    local file="$1"
    if [ ! -f "$file" ]; then
        print_message "WARNING" "Update list file not found: $file" >&2
        read -p "Do you want to create it? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_message "ERROR" "Cannot proceed without an update list file." >&2
            exit 1
        else
            create_update_list "$file"
        fi
    fi

    local packages=()
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*\"([^\"]+)\"[[:space:]]*=[[:space:]]*\".*\"[[:space:]]*$ ]]; then
            local package="${BASH_REMATCH[1]}"
            if [ -n "$package" ]; then
                packages+=("$package")
            fi
        fi
    done < "$file"

    if [ "$VERBOSE" = true ]; then
        print_message "DEBUG" "Packages found in file:" >&2
        for pkg in "${packages[@]}"; do
            print_message "DEBUG" "  $pkg" >&2
        done
    fi

    if [ ${#packages[@]} -eq 0 ]; then
        print_message "WARNING" "No valid packages found in the update list file." >&2
        read -p "Do you want to add packages now? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            add_packages_interactive "$file"
            # Re-read the file after adding packages
            packages=()
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*\"([^\"]+)\"[[:space:]]*=[[:space:]]*\".*\"[[:space:]]*$ ]]; then
                    local package="${BASH_REMATCH[1]}"
                    if [ -n "$package" ]; then
                        packages+=("$package")
                    fi
                fi
            done < "$file"
        else
            print_message "INFO" "No packages to check. Exiting." >&2
            exit 0
        fi
    fi

    printf '%s\n' "${packages[@]}"
}

create_update_list() {
    local file="${1:-$UPDATE_LIST_FILE}"
    print_message "INFO" "Creating update list file: $file"
    
    # Ensure the directory exists
    mkdir -p "$(dirname "$file")"
    
    # Create or truncate the file
    if > "$file"; then
        print_message "SUCCESS" "Created new update list file: $file"
        # Add a comment to the file to show it's been created
        echo "# Update list created on $(date)" >> "$file"
        echo "# Add packages in the format: \"package_name\" = \"\"" >> "$file"
    else
        print_message "ERROR" "Failed to create update list file: $file"
        exit 1
    fi
}

add_to_update_list() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if grep -q "^\"$pkg\"" "$UPDATE_LIST_FILE"; then
            print_message "WARNING" "Package $pkg already in the update list."
        else
            echo "\"$pkg\" = \"\"" >> "$UPDATE_LIST_FILE"
            print_message "SUCCESS" "Added $pkg to the update list."
        fi
    done
}

remove_from_update_list() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if sed -i "/^\"$pkg\"/d" "$UPDATE_LIST_FILE"; then
            print_message "SUCCESS" "Removed $pkg from the update list."
        else
            print_message "WARNING" "Package $pkg not found in the update list."
        fi
    done
}

add_packages_interactive() {
    local file="$1"
    print_message "INFO" "Enter package names (one per line). Press Ctrl+D or enter an empty line when finished:"
    while IFS= read -r package; do
        if [ -z "$package" ]; then
            break
        fi
        if ! grep -q "^\"$package\"[[:space:]]*=" "$file"; then
            echo "\"$package\" = \"\"" >> "$file"
            print_message "SUCCESS" "Added $package to the update list."
        else
            print_message "WARNING" "Package $package already in the update list."
        fi
    done
}

main() {
    local check_system=false
    local packages=()
    local AUTO_UPDATE=false
    local use_update_list=false
    local create_list=false
    local add_packages=false
    local remove_packages=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -s|--system)
                check_system=true
                ;;
            -l|--log)
                LOG_FILE="$SCRIPT_DIR/check_update.log"
                ;;
            -u|--update)
                AUTO_UPDATE=true
                ;;
            -f|--file)
                if [[ -n "$2" && "$2" != -* ]]; then
                    UPDATE_LIST_FILE="$2"
                    shift
                fi
                use_update_list=true
                ;;
            -c|--create)
                create_list=true
                ;;
            -a|--add)
                add_packages=true
                ;;
            -r|--remove)
                remove_packages=true
                ;;
            *)
                packages+=("$1")
                ;;
        esac
        shift
    done

    if [ "$VERBOSE" = true ]; then
        setup_logging
    fi

    if [ "$create_list" = true ]; then
        create_update_list
        exit 0
    fi

    if [ "$add_packages" = true ]; then
        add_to_update_list "${packages[@]}"
        exit 0
    fi

    if [ "$remove_packages" = true ]; then
        remove_from_update_list "${packages[@]}"
        exit 0
    fi

    if [ "$check_system" = true ] || [ ${#packages[@]} -eq 0 ] && [ "$use_update_list" = false ]; then
        check_and_update_system
    fi

    if [ "$use_update_list" = true ]; then
        print_message "INFO" "Using update list from: $UPDATE_LIST_FILE"
        if [ ! -f "$UPDATE_LIST_FILE" ]; then
            create_update_list "$UPDATE_LIST_FILE"
        fi
        readarray -t packages < <(parse_update_list "$UPDATE_LIST_FILE")
        
        if [ ${#packages[@]} -eq 0 ]; then
            print_message "ERROR" "No valid packages in the update list. Please add packages and try again."
            exit 1
        fi
        
        print_message "INFO" "Packages to check:"
        printf '  %s\n' "${packages[@]}"
    fi

    if [ ${#packages[@]} -gt 0 ]; then
        print_message "INFO" "Processing packages..."
        for pkg in "${packages[@]}"; do
            check_and_update_package "$pkg"
        done
    else
        print_message "INFO" "No packages specified for update check."
    fi
}

main "$@"
