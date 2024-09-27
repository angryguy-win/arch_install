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
    print_message INFO "Cleaning up..."
    # Add any necessary cleanup logic here
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Function to handle errors
handle_error() {
    print_message ERROR "An error occurred on line $1"
    exit 1
}

# Trap for error handling
trap 'handle_error $LINENO' ERR

# Function to install a package
install_package() {
    local package=$1
    if pacman -Qi "$package" &> /dev/null; then
        print_message NOTE "$package is already installed"
    else
        print_message INFO "Installing $package"
        if sudo pacman -S --noconfirm "$package"; then
            print_message OK "$package installed successfully"
        else
            print_message ERROR "Failed to install $package"
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

    print_message INFO "Installing Neovim and its dependencies"
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
    print_message OK "Created Neovim config directory: $config_dir"

    # Download Kickstart configuration
    if curl -fLo "$config_dir/init.lua" --create-dirs "$kickstart_url"; then
        print_message OK "Downloaded Kickstart Neovim configuration"
    else
        print_message ERROR "Failed to download Kickstart configuration"
        return 1
    fi

    # Install Packer (plugin manager)
    local packer_dir="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
    if [ ! -d "$packer_dir" ]; then
        git clone --depth 1 https://github.com/wbthomason/packer.nvim "$packer_dir"
        print_message OK "Installed Packer plugin manager"
    else
        print_message NOTE "Packer plugin manager already installed"
    fi

    # Run Neovim to install plugins
    print_message INFO "Installing Neovim plugins (this may take a while)..."
    nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
    print_message OK "Neovim plugins installed"

    return 0
}

# Main function
main() {
    print_message INFO "Starting Neovim installation and configuration process"

    if install_neovim && configure_neovim; then
        print_message OK "Neovim installed and configured successfully with Kickstart"
    else
        print_message ERROR "Failed to install or configure Neovim"
        exit 1
    fi
}

# Run the main function
main "$@"