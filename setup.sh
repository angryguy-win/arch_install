#!/bin/bash

# Update keyring and install git
pacman -Sy --noconfirm archlinux-keyring git

# Clone the repository
git clone https://github.com/angryguy-win/arch_install.git

# Change to the cloned directory
cd arch_install

# Run the installation script
sudo bash install.sh