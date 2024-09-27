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

# Function to install packages
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

# Function to install AUR packages
install_aur_package() {
    local package=$1
    if pacman -Qi "$package" &> /dev/null; then
        print_message NOTE "$package is already installed"
    else
        print_message INFO "Installing AUR package $package"
        if yay -S --noconfirm "$package"; then
            print_message OK "$package installed successfully"
        else
            print_message ERROR "Failed to install AUR package $package"
            return 1
        fi
    fi
}

# Function to install dependencies
install_dependencies() {
    local packages=(
        "fastfetch"
        "bat"
        "exa"
        "trash-cli"
        "multitail"
        "tree"
        "zoxide"
        "fzf"
        "neovim"
        "kitty"
        "xdotool"
        "starship"
        "yazi"
        "go"
    )

    local aur_packages=(
        "paru"
    )

    for package in "${packages[@]}"; do
        install_package "$package"
    done

    # Install yay if not already installed
    if ! command -v yay &> /dev/null; then
        print_message INFO "Installing yay..."
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi

    for package in "${aur_packages[@]}"; do
        install_aur_package "$package"
    done

    # Install Rust and Cargo
    if ! command -v rustc &> /dev/null; then
        print_message INFO "Installing Rust and Cargo..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
    fi

    # Install Atuin
    if ! command -v atuin &> /dev/null; then
        print_message INFO "Installing Atuin..."
        cargo install atuin
    fi

    # Install fzf-bash-completion
    if [ ! -f "$HOME/.local/share/fzf/fzf-bash-completion.sh" ]; then
        print_message INFO "Installing fzf-bash-completion..."
        mkdir -p "$HOME/.local/share/fzf"
        curl -o "$HOME/.local/share/fzf/fzf-bash-completion.sh" https://raw.githubusercontent.com/lincheney/fzf-tab-completion/master/bash/fzf-bash-completion.sh
    fi

    # Install Starship prompt
    if ! command -v starship &> /dev/null; then
        print_message INFO "Installing Starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi

    print_message OK "All dependencies installed successfully"
}

# Main function
main() {
    print_message INFO "Starting dependency installation process"

    if install_dependencies; then
        log_ok "All dependencies installed and configured successfully"
    else
        print_message ERROR "Failed to install dependencies"
        exit 1
    fi
}

# Run the main function
main "$@"