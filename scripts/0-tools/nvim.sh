#!/bin/bash

# Ensure ARCH_DIR is set and lib.sh can be sourced
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_FILE="$ARCH_DIR/lib/lib.sh"

[[ -z "$ARCH_DIR" ]] && { echo "Error: $SCRIPT_NAME: ARCH_DIR is not set"; exit 1; }
[[ -f "$LIB_FILE" ]] && source "$LIB_FILE" || { echo "Error: Failed to source $LIB_FILE"; exit 1; }

# Function to clean up on exit
cleanup() {
    log_info "Cleaning up..."
    # Add any necessary cleanup logic here
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Function to handle errors
handle_error() {
    log_error "An error occurred on line $1"
    exit 1
}

# Trap for error handling
trap 'handle_error $LINENO' ERR

# Function to install a package
install_package() {
    local package=$1
    if pacman -Qi "$package" &> /dev/null; then
        log_note "$package is already installed"
    else
        log_info "Installing $package"
        if sudo pacman -S --noconfirm "$package"; then
            log_ok "$package installed successfully"
        else
            log_error "Failed to install $package"
            return 1
        fi
    fi
}

# Function to install Neovim and dependencies
install_neovim() {
    local neovim_packages=(
        "neovim"
        "git"
        "base-devel"
        "ripgrep"
        "fd"
    )

    log_info "Installing Neovim and its dependencies"
    for package in "${neovim_packages[@]}"; do
        install_package "$package"
    done

    return 0
}

# Function to configure Neovim with Kickstart
configure_neovim() {
    local config_dir="$HOME/.config/nvim"
    local kickstart_url="https://raw.githubusercontent.com/nvim-lua/kickstart.nvim/master/init.lua"

    # Create Neovim config directory
    mkdir -p "$config_dir"
    log_ok "Created Neovim config directory: $config_dir"

    # Download Kickstart configuration
    if curl -fLo "$config_dir/init.lua" --create-dirs "$kickstart_url"; then
        log_ok "Downloaded Kickstart Neovim configuration"
    else
        log_error "Failed to download Kickstart configuration"
        return 1
    fi

    # Install Packer (plugin manager)
    local packer_dir="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
    if [ ! -d "$packer_dir" ]; then
        git clone --depth 1 https://github.com/wbthomason/packer.nvim "$packer_dir"
        log_ok "Installed Packer plugin manager"
    else
        log_note "Packer plugin manager already installed"
    fi

    # Run Neovim to install plugins
    log_info "Installing Neovim plugins (this may take a while)..."
    nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
    log_ok "Neovim plugins installed"

    return 0
}

# Main function
main() {
    log_info "Starting Neovim installation and configuration process"

    if install_neovim && configure_neovim; then
        log_ok "Neovim installed and configured successfully with Kickstart"
    else
        log_error "Failed to install or configure Neovim"
        exit 1
    fi
}

# Run the main function
main "$@"