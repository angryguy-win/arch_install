#!/bin/bash

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

# Global variables
VERBOSE=false
DRY_RUN=false
FORCE_UPDATE=false
PARALLEL_JOBS=4
LOG_FILE=""
PACKAGE_LIST_FILE=""
AUR_PACKAGE_MANAGER=${AUR_PACKAGE_MANAGER:-paru}
SKIP_INSTALLED=${SKIP_INSTALLED:-false}
SELECTED_PACKAGES=()
PROCESSED_PACKAGES=()
SKIPPED_PACKAGES=()
FAILED_PACKAGES=()
INSTALLED_PACKAGES=()
EXCLUDE_PACKAGES=()
OFFICIAL_INSTALL=()
AUR_INSTALL=()
GROUP_INSTALL=()

# @description Show help message
# @param None
# @return None
# @stdout Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Package Manager Script

Options:
  -h, --help                Show this help message and exit
  -v, --verbose             Enable verbose output
  -d, --dry-run             Perform a dry run without making any changes
  -i, --install [PACKAGE(S)] Install package(s). If no package is specified, install all from the master list
                            Can be a single package, a comma-separated list, or a file path
  -u, --uninstall [PACKAGE(S)] Uninstall package(s). If no package is specified, prompt for packages to uninstall
                            Can be a single package, a comma-separated list, or a file path
  -r, --remove PACKAGE(S)   Remove package(s) from the package list
                            Can be a single package, a comma-separated list, or a file path
  -e, --exclude PACKAGE(S)  Exclude package(s) from installation
                            Can be a single package or a comma-separated list
  -g, --generate            Generate a new package list
  -o, --output FILE         Specify output file for generated package list
  -l, --log-file [FILE]     Specify log file (default: package_manager.log)
  -f, --force-update        Force update of package list
  -j, --jobs NUMBER         Specify number of parallel jobs (default: 4)
  -s, --select PACKAGE(S)   Select specific package(s) for operation
                            Can be multiple packages specified separately

Examples:
  $(basename "$0") -i firefox               # Install Firefox
  $(basename "$0") -i firefox,chromium      # Install Firefox and Chromium
  $(basename "$0") -i packages.txt          # Install packages listed in packages.txt
  $(basename "$0") -i                       # Install all packages from the master list
  $(basename "$0") -u firefox               # Uninstall Firefox
  $(basename "$0") -r firefox,chromium      # Remove Firefox and Chromium from the package list
  $(basename "$0") -e firefox -i            # Install all packages except Firefox
  $(basename "$0") -g -o my_packages.toml   # Generate a new package list and save it as my_packages.toml
  $(basename "$0") -v -l custom.log -i      # Install all packages with verbose output and custom log file
  $(basename "$0") -d -i firefox            # Perform a dry run of installing Firefox
  $(basename "$0") -f -j 8 -i               # Force update package list, use 8 parallel jobs, and install all packages
  $(basename "$0") -s firefox chromium -i   # Select and install only Firefox and Chromium

For more information, please refer to the script documentation.
EOF
}
# @description Log message to file
# @param level Log level
# @param message Message to log
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp [$level] $message" >> "${LOG_FILE:-/dev/null}"
}
export -f log
# @description Print formatted messages
# @param type Message type
# @param message Message to print
print_message() {
    local type="${1:-INFO}"
    local message="${2:-No message provided}"
    local prefix_color=""
    local prefix="[$type]"

    if [[ -n "${COLORS[*]:-}" ]]; then
        case "$type" in
            INFO) prefix_color="${COLORS[BLUE]:-}"; prefix="[INFO]" ;;
            SUCCESS) prefix_color="${COLORS[GREEN]:-}"; prefix="[SUCCESS]" ;;
            WARNING) prefix_color="${COLORS[YELLOW]:-}"; prefix="[WARNING]" ;;
            ERROR) prefix_color="${COLORS[RED]:-}"; prefix="[ERROR]" ;;
            DRY-RUN) prefix_color="${COLORS[YELLOW]:-}"; prefix="[DRY-RUN]" ;;
            V) prefix_color="${COLORS[MAGENTA]:-}"; prefix="[V]" ;;
        esac
    fi

    printf "%b%s%b %s\n" "$prefix_color" "$prefix" "${COLORS[RESET]:-}" "$message"

    if [[ -n "${LOG_FILE:-}" ]]; then
        log "$type" "$message"
    fi
}
export -f print_message
export COLORS
export LOG_FILE
# @description Function to print verbose messages
# @param message Message to print
verbose_print() {
    local message="$1"
    if [[ "${VERBOSE:-false}" = true ]]; then
        print_message V "$message"
    fi
}
export -f verbose_print
# @description Generate package list
# @param output_file Output file path
generate_package_list() {
    local output_file="$1"
    local explicit_packages
    local aur_packages
    local package_groups

    print_message "INFO" "Generating package list..."

    explicit_packages=$(pacman -Qqen)
    aur_packages=$(pacman -Qqem)
    package_groups=$(pacman -Qg | cut -d' ' -f1 | sort -u)

    if [[ "$DRY_RUN" = true ]]; then
        print_message "DRY-RUN" "Would create package list: $output_file"
    else
        {
            echo "[official]"
            printf '"%s"\n' $explicit_packages
            echo "[aur]"
            printf '"%s"\n' $aur_packages
            echo "[groups]"
            printf '"%s"\n' $package_groups
        } > "$output_file"
        print_message "SUCCESS" "Package list generated: $output_file"
    fi
}
# @description Update package list
# @param None
# @return None
update_package_list() {
    local last_update_file="$SCRIPT_DIR/.last_package_list_update"
    local update_interval=$((7 * 24 * 60 * 60))  # 7 days in seconds

    if [[ -f "$last_update_file" ]]; then
        local last_update=$(cat "$last_update_file")
        local current_time=$(date +%s)
        if (( current_time - last_update > update_interval )); then
            print_message "INFO" "Package list is outdated. Updating..."
            generate_package_list "$PACKAGE_LIST_FILE"
            echo "$current_time" > "$last_update_file"
        else
            print_message "INFO" "Package list is up-to-date."
        fi
    else
        print_message "INFO" "Generating initial package list..."
        generate_package_list "$PACKAGE_LIST_FILE"
        date +%s > "$last_update_file"
    fi
    verbose_print "DEBUG: Package list contents:"
    #verbose_print "$(cat "$PACKAGE_LIST_FILE")"
}
# @description Check if package is installed
# @param package Package to check
is_package_installed() {
    local package="$1"
    if pacman -Qi "$package" &> /dev/null; then
        #verbose_print "DEBUG: Package $package is already installed"
        return 0
    else
        #verbose_print "DEBUG: Package $package is not installed"
        return 1
    fi
}
export -f is_package_installed
# @description Check if package is installed and up-to-date
# @param package Package to check
is_package_up_to_date() {
    local package="$1"
    verbose_print "DEBUG: Checking if package is up-to-date: $package"
    if $AUR_PACKAGE_MANAGER -Qu "$package" &>/dev/null; then
        verbose_print "DEBUG: Package $package is not up-to-date"
        return 1
    else
        verbose_print "DEBUG: Package $package is up-to-date"
        return 0
    fi
}

# @description Check if group is installed
# @param group Group to check
is_group_installed() {
    local group="$1"
    #verbose_print "DEBUG: Checking if group is installed: $group"
    if $AUR_PACKAGE_MANAGER -Qg "$group" &>/dev/null; then
        #verbose_print "DEBUG: Group $group is installed"
        return 0
    else
        #verbose_print "DEBUG: Group $group is not installed"
        return 1
    fi
}
# @description Handle installation
# @param None
# @return None
handle_installation() {
    verbose_print "Handling installation"
    verbose_print "INSTALL_MODE=$INSTALL_MODE"
    
    local to_install=()

    case "$INSTALL_MODE" in
        "file")
            verbose_print "Reading packages from file: $PACKAGE_LIST_FILE"
            if ! read_package_list; then
                print_message "ERROR" "Failed to read package list"
                return 1
            fi
            to_install+=("${OFFICIAL_INSTALL[@]}" "${AUR_INSTALL[@]}" "${GROUP_INSTALL[@]}")
            ;;
        "packages"|"list"|"single")
            verbose_print "Installing specified packages: ${INSTALL_PACKAGES[*]}"
            to_install+=("${INSTALL_PACKAGES[@]}")
            ;;
        "full")
            verbose_print "Performing full installation from master list"
            if ! read_package_list; then
                print_message "ERROR" "Failed to read package list"
                return 1
            fi
            to_install+=("${OFFICIAL_INSTALL[@]}" "${AUR_INSTALL[@]}" "${GROUP_INSTALL[@]}")
            ;;
        *)
            print_message "ERROR" "Invalid INSTALL_MODE: $INSTALL_MODE"
            return 1
            ;;
    esac

    if [ ${#to_install[@]} -gt 0 ]; then
        print_message "INFO" "Installing packages..."
        for pkg in "${to_install[@]}"; do
            if is_package_installed "$pkg"; then
                print_message "INFO" "Package $pkg is already installed. Skipping."
                SKIPPED_PACKAGES+=("$pkg")
            else
                print_message "INFO" "Installing package: $pkg"
                if [[ " ${AUR_INSTALL[*]} " =~ " ${pkg} " ]]; then
                    if ! package_install "$pkg" "AUR"; then
                        print_message "WARNING" "Failed to install $pkg"
                    fi
                else
                    if ! package_install "$pkg" "official"; then
                        print_message "WARNING" "Failed to install $pkg"
                    fi
                fi
            fi
        done
    else
        print_message "INFO" "No packages to install."
    fi

    print_message "INFO" "Installation process completed."
}
# @description Handle uninstallation
# @param None
# @return None
handle_uninstallation() {
    verbose_print "Handling uninstallation"
    verbose_print "UNINSTALL_MODE=$UNINSTALL_MODE"
    
    local to_uninstall=()

    if [ "$UNINSTALL_MODE" = "file" ]; then
        verbose_print "Reading packages from file: $PACKAGE_LIST_FILE"
        if ! read_package_list; then
            print_message "ERROR" "Failed to read package list"
            return 1
        fi
        to_uninstall+=("${OFFICIAL_UNINSTALL[@]}" "${AUR_UNINSTALL[@]}" "${GROUP_UNINSTALL[@]}")
    elif [ "$UNINSTALL_MODE" = "packages" ] || [ "$UNINSTALL_MODE" = "list" ] || [ "$UNINSTALL_MODE" = "single" ]; then
        verbose_print "Uninstalling specified packages: ${UNINSTALL_PACKAGES[*]}"
        to_uninstall+=("${UNINSTALL_PACKAGES[@]}")
    else
        print_message "ERROR" "Invalid UNINSTALL_MODE: $UNINSTALL_MODE"
        return 1
    fi
    
    if [ ${#to_uninstall[@]} -gt 0 ]; then
        print_message "INFO" "Uninstalling packages..."
        for pkg in "${to_uninstall[@]}"; do
            # Remove any remaining quotes
            pkg=$(echo "$pkg" | sed -e 's/^"//' -e 's/"$//')

            if ! pacman -Ss "^$pkg$" > /dev/null 2>&1; then
                print_message "WARNING" "Package $pkg does not exist in the repositories. Skipping."
                SKIPPED_PACKAGES+=("$pkg")
                continue
            fi

            if [ ${#SELECTED_PACKAGES[@]} -eq 0 ] || [[ " ${SELECTED_PACKAGES[*]} " =~ " ${pkg} " ]]; then
                if is_package_installed "$pkg"; then
                    print_message "INFO" "Uninstalling package: $pkg"
                    if [ "$DRY_RUN" = true ]; then
                        print_message "DRY-RUN" "Would uninstall package: $pkg"
                        PROCESSED_PACKAGES+=("$pkg")
                    else
                        # Determine package type
                        local pkg_type="official"
                        if [[ " ${AUR_UNINSTALL[*]} " =~ " ${pkg} " ]]; then
                            pkg_type="AUR"
                        elif [[ " ${GROUP_UNINSTALL[*]} " =~ " ${pkg} " ]]; then
                            pkg_type="group"
                        fi

                        if uninstall_package "$pkg" "$pkg_type"; then
                            print_message "SUCCESS" "Successfully uninstalled $pkg"
                        else
                            print_message "ERROR" "Failed to uninstall $pkg"
                        fi
                    fi
                else
                    print_message "INFO" "Package $pkg is not installed. Skipping."
                    SKIPPED_PACKAGES+=("$pkg")
                fi
            else
                print_message "INFO" "Package $pkg is not selected for uninstallation."
                SKIPPED_PACKAGES+=("$pkg")
            fi
        done
    else
        print_message "INFO" "No packages to uninstall."
    fi

    print_message "INFO" "Uninstallation process completed."
}
# @description Check package status
# @param pkg Package to check   
# @return Status of the package
check_package() {
    local pkg="$1"
    if [[ -z "$pkg" ]]; then
        printf "%s\n" "ERROR"
        return
    fi
    if is_package_installed "$pkg"; then
        printf "%s\n" "SKIP"
    elif [[ " ${SELECTED_PACKAGES[*]} " =~ " ${pkg} " ]] || [[ ${#SELECTED_PACKAGES[@]} -eq 0 ]]; then
        printf "%s\n" "INSTALL"
    else
        printf "%s\n" "EXCLUDE"
    fi
}
export -f check_package

# @description Install packages
# @param type Package type (official, AUR, or group)
# @param packages Array of packages to install
install_packages() {
    local type="$1"
    shift
    local packages=("$@")
    local to_install=()
    local installed_count=0
    local skipped_count=0
    local failed_count=0
    local total=${#packages[@]}

    print_message "INFO" "Checking $type packages..."
    verbose_print "DEBUG: Processing $type packages: ${packages[*]}"

    # Use parallel with --env to pass necessary variables and functions
    results=$(parallel --env VERBOSE,FORCE_UPDATE,SELECTED_PACKAGES,DRY_RUN,AUR_PACKAGE_MANAGER,LOG_FILE \
                       --env log,print_message,is_package_installed,verbose_print \
                       --keep-order --line-buffer \
                       check_package ::: "${packages[@]}")

    while IFS= read -r line; do
        local pkg=$(echo "$line" | cut -d' ' -f1)
        local status=$(echo "$line" | cut -d' ' -f2)
        
        if [[ -n "$pkg" ]]; then
            case "$status" in
                "SKIP")
                    print_message "INFO" "Skipping $type package: $pkg (already installed)"
                    ((skipped_count++))
                    ;;
                "EXCLUDE")
                    verbose_print "DEBUG: Excluding package: $pkg"
                    ;;
                "INSTALL")
                    to_install+=("$pkg")
                    ;;
                *)
                    print_message "WARNING" "Unknown status for package $pkg: $status"
                    ;;
            esac
        else
            print_message "WARNING" "Empty package name encountered"
        fi
    done <<< "$results"

    for pkg in "${to_install[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            print_message "DRY-RUN" "Would install $type package: $pkg"
            ((installed_count++))
        else
            print_message "INFO" "Installing $type package: $pkg"
            if package_install "$pkg" "$type"; then
                print_message "SUCCESS" "Successfully installed $pkg"
                ((installed_count++))
            else
                print_message "WARNING" "Failed to install $pkg"
                ((failed_count++))
            fi
        fi
    done

    print_message "INFO" "$type package installation complete. Installed: $installed_count, Skipped: $skipped_count, Failed: $failed_count, Total: $total"
    
    if [[ $failed_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}
# @description Install AUR package
# @param package Package to install 
# @return 0 if successful, 1 if failed
install_aur_package() {
    local package="$1"
    if [ "$DRY_RUN" = true ]; then
        print_message "DRY-RUN" "Would install AUR package: $package"
    else
        print_message "INFO" "Installing AUR package: $package"
        if paru -S --noconfirm "$package"; then
            print_message "SUCCESS" "Successfully installed $package"
        else
            print_message "ERROR" "Failed to install $package"
        fi
    fi
}
# @description Install package groups
# @param groups Array of package groups to install
install_package_groups() {
    local groups=("$@")
    local installed_count=0
    local skipped_count=0
    local excluded_count=0
    local failed_count=0

    for group in "${groups[@]}"; do
        if is_group_installed "$group"; then
            print_message "INFO" "Skipping group: $group (already installed)"
            ((skipped_count++))
        else
            print_message "INFO" "Installing package group: $group"
            if [[ "$DRY_RUN" == "true" ]]; then
                print_message "DRY-RUN" "Would install package group: $group"
                ((installed_count++))
            else
                if $AUR_PACKAGE_MANAGER -S --needed --noconfirm "$group"; then
                    print_message "SUCCESS" "Successfully installed group $group"
                    ((installed_count++))
                else
                    print_message "WARNING" "Failed to install group $group"
                    ((failed_count++))
                fi
            fi
        fi
    done

    print_message "INFO" "Package group installation complete. Installed: $installed_count, Skipped: $skipped_count, Excluded: $excluded_count, Failed: $failed_count, Total: ${#groups[@]}"
    
    if [[ $failed_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}
# @description Package install function
# @param package Package to install
# @param type Package type
package_install() {
    local package="$1"
    local type="$2"
    
    if [ "$DRY_RUN" = true ]; then
        print_message "DRY-RUN" "Would install $type package: $package"
        PROCESSED_PACKAGES+=("$package")
        return 0
    else
        print_message "INFO" "Installing $type package: $package"
        if [ "$type" = "AUR" ]; then
            if $AUR_PACKAGE_MANAGER -S --noconfirm "$package"; then
                print_message "SUCCESS" "Successfully installed $package"
                PROCESSED_PACKAGES+=("$package")
                return 0
            else
                print_message "ERROR" "Failed to install $package"
                FAILED_PACKAGES+=("$package")
                return 1
            fi
        else
            if sudo pacman -S --noconfirm --needed "$package"; then
                print_message "SUCCESS" "Successfully installed $package"
                PROCESSED_PACKAGES+=("$package")
                return 0
            else
                print_message "ERROR" "Failed to install $package"
                FAILED_PACKAGES+=("$package")
                return 1
            fi
        fi
    fi
}
# @description Uninstall packages
# @param packages Array of packages to uninstall   
# @return 0 if successful, 1 if failed
# @stdout Failed packages
# @stderr Error message
uninstall_packages() {
    local packages=("$@")
    local failed_packages=()

    for pkg in "${packages[@]}"; do
        print_message "INFO" "Attempting to uninstall package: $pkg"
        if is_package_installed "$pkg"; then
            local pkg_type="official"
            if [[ " ${AUR_UNINSTALL[*]} " =~ " ${pkg} " ]]; then
                pkg_type="AUR"
            elif [[ " ${GROUP_UNINSTALL[*]} " =~ " ${pkg} " ]]; then
                pkg_type="group"
            fi

            if ! uninstall_package "$pkg" "$pkg_type"; then
                failed_packages+=("$pkg")
            fi
        else
            print_message "WARNING" "Package $pkg is not installed"
        fi
    done

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_message "ERROR" "Failed to uninstall the following packages: ${failed_packages[*]}"
        return 1
    fi

    return 0
}
# @description Uninstall a single package
# @param package Package to uninstall
# @param type Package type (official, AUR, or group)
uninstall_package() {
    local package="$1"
    local type="$2"
    
    if [ "$DRY_RUN" = true ]; then
        print_message "DRY-RUN" "Would uninstall $type package: $package"
        PROCESSED_PACKAGES+=("$package")
        return 0
    else
        print_message "INFO" "Uninstalling $type package: $package"
        if [ "$type" = "AUR" ]; then
            if $AUR_PACKAGE_MANAGER -R --noconfirm "$package"; then
                PROCESSED_PACKAGES+=("$package")
                return 0
            else
                print_message "ERROR" "Failed to uninstall $package"
                FAILED_PACKAGES+=("$package")
                return 1
            fi
        else
            if sudo pacman -R --noconfirm "$package"; then
                PROCESSED_PACKAGES+=("$package")
                return 0
            else
                print_message "ERROR" "Failed to uninstall $package"
                FAILED_PACKAGES+=("$package")
                return 1
            fi
        fi
    fi
}
export -f uninstall_package
# @description Read package list from TOML file
# @param None
# @return None
read_package_list() {
    verbose_print "DEBUG: Reading package list from $PACKAGE_LIST_FILE"
    OFFICIAL_INSTALL=()
    OFFICIAL_UNINSTALL=()
    AUR_INSTALL=()
    AUR_UNINSTALL=()
    GROUP_INSTALL=()
    GROUP_UNINSTALL=()
    
    local current_section=""
    local current_action=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove leading/trailing whitespace and quotes
        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
        
        case "$line" in
            '[official]'|'[aur]'|'[groups]')
                current_section="${line:1:-1}"
                ;;
            'install = ['|'uninstall = [')
                current_action="${line%% *}"
                ;;
            *',')
                # Remove trailing comma and any surrounding quotes
                package="${line%,}"
                package="${package#\"}"
                package="${package%\"}"
                case "$current_section" in
                    "official")
                        if [[ "$current_action" == "install" ]]; then
                            OFFICIAL_INSTALL+=("$package")
                        else
                            OFFICIAL_UNINSTALL+=("$package")
                        fi
                        ;;
                    "aur")
                        if [[ "$current_action" == "install" ]]; then
                            AUR_INSTALL+=("$package")
                        else
                            AUR_UNINSTALL+=("$package")
                        fi
                        ;;
                    "groups")
                        if [[ "$current_action" == "install" ]]; then
                            GROUP_INSTALL+=("$package")
                        else
                            GROUP_UNINSTALL+=("$package")
                        fi
                        ;;
                esac
                ;;
        esac
    done < "$PACKAGE_LIST_FILE"
    
    verbose_print "DEBUG: Read ${#OFFICIAL_INSTALL[@]} official packages to install, ${#OFFICIAL_UNINSTALL[@]} to uninstall"
    verbose_print "DEBUG: Read ${#AUR_INSTALL[@]} AUR packages to install, ${#AUR_UNINSTALL[@]} to uninstall"
    verbose_print "DEBUG: Read ${#GROUP_INSTALL[@]} package groups to install, ${#GROUP_UNINSTALL[@]} to uninstall"
}
# @description Parse TOML and extract package lists
# @param file TOML file path
# @param type Type of packages to extract
parse_package_list() {
    local file="$1"
    local type="$2"
    local section=""
    local in_target_section=false
    
    while IFS= read -r line; do
        if [[ $line == "[$type]" ]]; then
            in_target_section=true
        elif [[ $line == \[*] ]]; then
            in_target_section=false
        elif [[ $in_target_section == true && $line =~ ^\"(.+)\"$ ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done < "$file"
}

# @description Check if package should be excluded
# @param package Package to check
should_exclude() {
    local package="$1"
    for excluded in "${EXCLUDE_PACKAGES[@]}"; do
        if [[ "$package" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}
export -f should_exclude

# @description Error handler
# @param exit_code Exit code
# @param line_no Line number
error_handler() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        local line_number=$LINENO
        local command="${BASH_COMMAND}"
        print_message "ERROR" "Command '${command}' failed with exit code ${exit_code} on line ${line_number}"
    fi
}
export -f error_handler
# @description Setup error handling
# @param None
# @return None
setup_error_handling() {
    echo "DEBUG: Entering setup_error_handling"
    set -o errexit
    set -o pipefail
    set -o nounset
    echo "DEBUG: Shell options set"
    verbose_print "Setting up error handling..."
    echo "DEBUG: verbose_print called"

    trap 'error_handler' ERR
    trap 'handle_error $? $LINENO' ERR
    trap handle_sudo_timeout SIGALRM
    echo "DEBUG: Trap set"

    error_handler
    echo "DEBUG: Exiting setup_error_handling"
} 
# @description Cleanup handler
# @param None
# @return None
cleanup_handler() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_message "WARNING" "Script encountered errors. Exit code: ${COLORS[RED]}$exit_code${COLORS[RESET]}"
    else
        verbose_print "Exit code: ${COLORS[GREEN]}$exit_code${COLORS[RESET]}"
        print_message "INFO" "Script completed successfully"
    fi
}

# @description Setup logging
# @param None
# @return None
setup_logging() {
    verbose_print "Setting up logging..."
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
        print_message "INFO" "Logging output to: $LOG_FILE"
    else
        print_message "INFO" "No log file specified. Logging to console only."
    fi
}

# @description Get system information
# @param None
# @return None
get_system_info() {
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')
    local total_memory=$(free -h | awk '/^Mem:/ {print $2}')
    local disk_space=$(df -h / | awk 'NR==2 {print $2}')
    
    print_message "INFO" "System Information:"
    print_message "INFO" "CPU: ${cpu_model}"
    print_message "INFO" "Total Memory: ${total_memory}"
    print_message "INFO" "Disk Space: ${disk_space}"
    print_message "INFO" "Library version: ${LIB_VERSION:-Unknown}"
    print_message "INFO" "Path: ${PWD}"
}
# @description Print operation summary  
# @param operation Operation name
# @param operation_past_tense Past tense of the operation name
# @return None
print_operation_summary() {
    local operation="$1"
    local action="$2"
    print_message "INFO" "${operation^} Summary:"
    print_message "INFO" "--------------------"
    print_message "INFO" "${action^} packages (${#PROCESSED_PACKAGES[@]}):"
    for pkg in "${PROCESSED_PACKAGES[@]}"; do
        print_message "INFO" "  - $pkg"
    done
    if [ ${#SKIPPED_PACKAGES[@]} -gt 0 ]; then
        print_message "INFO" "Skipped packages (${#SKIPPED_PACKAGES[@]}):"
        for pkg in "${SKIPPED_PACKAGES[@]}"; do
            print_message "INFO" "  - $pkg"
        done
    fi
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        print_message "INFO" "Failed packages (${#FAILED_PACKAGES[@]}):"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            print_message "INFO" "  - $pkg"
        done
    fi
    print_message "INFO" "--------------------"
}
# @description Log resource usage
# @param None
# @return None
log_resource_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0"%"}')
    local disk_usage=$(df -h / | awk '/\// {print $5}')
    
    print_message "INFO" "Resource usage - CPU: $cpu_usage, Memory: $mem_usage, Disk: $disk_usage"
}
check_for_updates() {
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
        printf "%s\n" "$updates"
    fi
}
confirm_installation() {
    local packages=("$@")
    print_message "INFO" "The following packages will be installed:"
    printf '  %s\n' "${packages[@]}"
    read -p "Do you want to proceed? [Y/n] " -n 1 -r
    printf "\n"
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        return 0
    else
        return 1
    fi
}
handle_sudo_timeout() {
    print_message "ERROR" "Sudo password prompt timed out. Please run the script again and enter your password promptly."
    exit 1
}
check_package_updates() {
    local package="$1"
    local local_version remote_version

    # Get the local version of the package
    local_version=$(pacman -Q "$package" 2>/dev/null | awk '{print $2}')
    if [ -z "$local_version" ]; then
        print_message "INFO" "Package $package is not installed."
        return 1
    fi

    # Get the remote version of the package
    remote_version=$(pacman -Si "$package" 2>/dev/null | grep 'Version' | awk '{print $3}')
    if [ -z "$remote_version" ]; then
        print_message "INFO" "Package $package is not available in the repositories."
        return 1
    fi

    # Compare versions
    if [ "$local_version" != "$remote_version" ]; then
        print_message "INFO" "Update available for package $package: $local_version -> $remote_version"
        return 0
    else
        print_message "INFO" "Package $package is up-to-date."
        return 0
    fi
}
# End of lib_tools.sh