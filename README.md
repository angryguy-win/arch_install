# Arch install Script
## This is still in development work in progress.
## need more live install testing.
## still ironning out the kinks and making sure it works for all cases.

run the install script ` bash install.sh `
The script is broken down into 6 parts
1. PreInstall
2. Drives
3. Base install and system
4. Post install
5. Desktop
6. Final and clean up

For example it could be used whit somthing like this:
( https://github.com/angryguy-win/Rust-Arch-menu )
arch_config.toml
Key = Varible pair list is used for the install.
Or it could just be edited manualy for use with other scripts.

### General break down of the project.
- config
  - bashrc
  - zshrc
  - starship.toml
  - alacritty.yml
  - nvim
- Lib
  - lib.sh
- Logs:
- |
- Scripts:
  - 0-tools
    - package-manager.sh
  - 1-pre
    - pre-setup.sh
    - run-checks.sh
    - sync-mirrors.sh
  - 2 -drive
    - format-btrfa.sh
    - partion-btrfs.sh
    - format-ext4.sh
    - partion-ext4.sh
  - 3-base
    - bootstrap-pkgs.sh
    - generate-fstab.sh
  - 4-post
    - conf-mkinitpio.sh
    - setup-grub-btrfs.sh
    - sync-mirrors.sh
    - system.conf.sh
    - system-pkg.sh
    - terminal.sh
  - 5-desktop
    - dwm.sh
    - gnome.sh
    - kde.sh
  - 6-final
    - last-cleanuo.sh
- |
- gitignore
- acrh_config.cfg
- arch_config.toml
- install.conf
- install.sh
- test_config.sh
- LICENSE
- README.md
- stages.toml


## Program functions/Modules

DRY_RUN is a true/false variable that is used to enable or disable dry run mode.
When set to true, the script will not execute any commands and will only print 
the commands that would have been executed.
```bash
sudo bash install.sh --dry-run
# Example output
[INFO] Starting stage:  1-pre
[INFO] Executing:  1-pre/pre-setup.sh
[ACTION] - Would execute: bash /home/ssnow/projects/arch-install/scripts/1-pre/pre-setup.sh   (Script: pre-setup.sh)
```
DEBUG_MODE is a true/false variable that is used to enable or disable debug mode.
When set to true, the script will print out more information about the script and the variables.
```bash
sudo bash install.sh --debug
# Example output
[DEBUG] Format type:  [DEBUG] Retrieved from config file:  format_type=btrfs
[DEBUG] Final value for:  format_type=btrfs
[DEBUG] Desktop environment:  [DEBUG] Retrieved from config file:  desktop_environment=gnome
[DEBUG] Final value for:  desktop_environment=gnome
[INFO] Starting stage:  1-pre
[INFO] Executing:  1-pre/pre-setup.sh
[DEBUG] Script path:  /home/ssnow/projects/arch-install/scripts/1-pre/pre-setup.sh
[DEBUG] DRY_RUN value before execution: true
```

### The install configuration file <arch_config.toml>
```bash
hostname = 'archlinux'
username = 'user'
password = 'changeme'
timezone = 'America/Toronto'
locale = 'en_US.UTF-8'
keyboard_layout = 'us'
keymap = 'en'
package_manager = 'paru'
bootloader = 'grub'
desktop_environment = 'gnome'
reflector_country = 'CA'
microcode = 'amd'
use_luks = false
luks_password = 'changeme'
install_device = 'nvme3n1'
partition1 = '/dev/nvme3n1p1'
partition2 = '/dev/nvme3n1p2'
partition3 = '/dev/nvme3n1p3'
shell = 'bash'
terminal = 'alacritty'
enable_ssh = true
format_type = 'btrfs'
sub_volumes = '@,@home,@var,@tmp,@.snapshots'
subvol_dir = 'boot/efi,home,.snapshots,var/{cache,var/log}'
device_type = 'ssd'
grub_theme = 'CyberRe'
load_themes = true

```

### Install script

- This script does the following:
1. It defines the path to the stages.toml file.
2. It includes a parse_stages_toml function that reads the TOML file and populates 
  the INSTALL_SCRIPTS associative array.
3. It calls parse_stages_toml to set up the installation stages and scripts.
4. It creates a sorted list of stages based on the keys in INSTALL_SCRIPTS.
5. It prints out the parsed stages and scripts for verification.
6. The main execution flow remains the same, using the parsed stages and scripts.

Ensure that the TOML file follows the expected format.
stages.toml
```shell
[stages]
"1-pre" = ["pre-setup.sh", "run-checks.sh"]
"2-drive" = ["partition-btrfs.sh", "format-btrfs.sh"]
"3-base" = ["bootstrap-pkgs.sh", "generate-fstab.sh"]
"4-post" = ["system-conf.sh", "system-pkgs.sh", "terminal.sh"]
"5-desktop" = ["gnome.sh"]
"6-final" = ["last-cleanup.sh"]
```

```shell
# Parse the stages TOML file
parse_stages_toml "$STAGES_CONFIG" || print_message ERROR "Failed to parse stages.toml" exit 1

# Create a sorted list of stages
readarray -t SORTED_STAGES < <(printf '%s\n' "${!INSTALL_SCRIPTS[@]}" | sort)

# Print the INSTALL_SCRIPTS array for verification
print_message INFO "Installation Stages and Scripts:"
for stage in "${SORTED_STAGES[@]}"; do
    print_message INFO "  $stage: ${INSTALL_SCRIPTS[$stage]}"
done
# ---------------
# Run the install scripts is run in main()
run_install_scripts "$format_type" "$desktop_environment" || { print_message ERROR "Installation failed"; return 1; }

```

### Info tags
The info tags are used to print messages to the log file.
and also print to the console.
```shell
# LEVEL = [INFO, ACTION, DEBUG, ERROR, WARNING, OK, NOTE]
# MESSAGE = Main message

``` 
```bash
print_message PROC "Print configuration: ${YELLOW}Info:"

print_message INFO "Loading config for" "$var_name"
print_message ACTION "Would set $key=$value in $config_file" "(Config: $config_file)"
```
### Storing local variable.
variable is used to store the value of a variable. in the <arch_config.cfg> file.
```bash
# set_option "<KEY>" "<VARIABLE>"
set_option "BOOT_DEVICE" "/dev/disk/by-partlabel/BOOT"
```


### Loading configurations

1. load_config:
-  Takes multiple variable names as arguments.
-  Loads values for all specified variables from the config file.
-  Sets these values as global variables in the script.
-  Handles error checking for missing values.
-  Provides more detailed logging.

2. get_config_value:
-  Takes a single key as an argument.
-  Retrieves the value for that specific key from the config file or memory.
-  Returns the value (doesn't set global variables).
-  Handles default values.
-  Provides more granular control over retrieving individual values.
  
3. They serve different purposes and can be used in different scenarios:

- Use load_config when:
  - You need to load multiple configuration values at once.
  - You want these values to be set as global variables in your script.
  - You want automatic error handling for missing values.
- Use get_config_value when:
  - You need to retrieve a single configuration value.
  - You don't necessarily want to set a global variable.
  - You need more control over how the value is used or processed.
  - You want to provide a default value if the key is not found.
```shell
    # Load configuration
    local vars=(format_type desktop_environment)
    load_config "${vars[@]}" || { print_message ERROR "Failed to load config"; return 1; }
```

### Script logic <run_steps()>
implements the run_commands_with_messages function, the dry_run flag,
process_init. it also handle all the logging and error handling.
You can use this function to run multiple commands and messages.
There are other ways of using these functions.
You are limited to this template or you could add more to it.
```bash
--error-handler
--success-handler
--debug
--dry-run
--command
--message
--pre-command-hook
--post-command-hook
--use-chroot

```
```bash
example_function() {
    local commands
    local messages

    commands=(
        "command4"
        "command5"
    )

    messages=(
        "Executing command 4"
        "Executing command 5"
    )

    for i in "${!commands[@]}"; do
        args+=(--command "${commands[$i]}" --message "${messages[$i]}")
    done
    execute_process "Network Setup Configuration" \
        --debug \
        --error-message "Failed to setup network" \
        --success-message "Network setup completed successfully" \
        "${args[@]}"
        # --use-chroot # Uncomment to use chroot optional
}
```
There are other ways to use this function.
```bash

    # Common settings
    commands+=("set_option partition1 \"${install_device}1\"")
    messages+=("Setting partition1")
    commands+=("set_option partition2 \"${install_device}2\"")
    messages+=("Setting partition2")

    for script in "${INSTALL_SCRIPTS[@]}"; do
        commands+=("bash $SCRIPTS_DIR/$script")
        messages+=("Executing $script")
    done
```

## Package-manager

This tool is used to install, uninstall, and manage packages.
It will also generate a package list. from your current system as a master list.
this can be used to reinstall your system.
It can be used to install packages from the repo by categories: bin, aur and groups.
You can create your own package list.toml file. for different scenarios and your needs.
just follow the format.

```bash
bash package_manager.sh -h
Usage: package_manager.sh [OPTIONS]

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
  package_manager.sh -i firefox               # Install Firefox
  package_manager.sh -i firefox,chromium      # Install Firefox and Chromium
  package_manager.sh -i packages.txt          # Install packages listed in packages.txt
  package_manager.sh -i                       # Install all packages from the master list
  package_manager.sh -u firefox               # Uninstall Firefox
  package_manager.sh -r firefox,chromium      # Remove Firefox and Chromium from the package list
  package_manager.sh -e firefox -i            # Install all packages except Firefox
  package_manager.sh -g                       # Generate a new package list default: package_list.toml
  package_manager.sh -g -o my_packages.toml   # Generate a new package list and save it as my_packages.toml
  package_manager.sh -v -l custom.log -i      # Install all packages with verbose output and custom log file
  package_manager.sh -d -i firefox            # Perform a dry run of installing Firefox
  package_manager.sh -f -j 8 -i               # Force update package list, use 8 parallel jobs, and install all packages
  package_manager.sh -s firefox chromium -i   # Select and install only Firefox and Chromium

For more information, please refer to the script documentation.
```
### Checking updates
Create a list of packages to check for updates. so that this Only updates the list.
you can add or remove packages from the list.
You can also check for system-wide updates.
keep track of the updates.

```bash
bash check_update.sh -h
Usage: check_update.sh [options] [package1] [package2] ...
Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -s, --system   Check for system-wide updates
  -l, --log      Log output to file
  -u, --update   Update packages if available
  -f, --file     Specify a custom update list file (default: update_list.toml)
  -c, --create   Create a new update list file
  -a, --add      Add packages to the update list
  -r, --remove   Remove packages from the update list
If no packages are specified, only system-wide updates will be checked.
```
### Recovery
```bash
TODO this is a work in progress.
still in development.
```

### Install sample output
<Show the DRY_RUN output>![alt text](image-1.png)

Dry run output:
```bash
bash install.sh --dry-run
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Main Installation Process (ID: 1726232000)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Arch Linux Installer
------------------------------------------------------------------------

[INFO] Welcome to the Arch Linux installer script
[PROC] DRY_RUN is set to: true
[PROC] Print configuration: Info:
[INFO] --- System Information ---
[INFO] Getting RAM information
[INFO] RAM:  61.9 GB
[INFO] Getting CPU information
[INFO] CPU Model:  AMD Ryzen 9 7900X3D 12-Core Processor
[INFO] CPU Cores:  24
[INFO] CPU Threads:  24
[INFO] The drive list
      1) sda     931.5G Samsung SSD 870 QVO 1TB
      2) nvme0n1   1.8T Samsung SSD 980 PRO 2TB
      3) nvme1n1 931.5G Samsung SSD 980 PRO 1TB
      4) nvme3n1 931.5G Sabrent SB-RKT4P-1TB
      5) nvme2n1 476.9G Samsung SSD 960 PRO 512GB
[INFO] Getting GPU information
[INFO] GPU Location:   03:00.0 VGA compatible
[INFO] GPU Details:    VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c0)
[INFO] GPU Location:   03:00.1 Audio device:
[INFO] GPU Details:    Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21/23 HDMI/DP Audio Controller
[INFO] GPU Location:   16:00.0 VGA compatible
[INFO] GPU Details:    VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Raphael (rev ca)
[INFO] GPU Location:   16:00.1 Audio device:
[INFO] GPU Details:    Audio device: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt Radeon High Definition Audio Controller
lspci: Unable to load libkmod resources: error -2
[INFO] GPU Part 1:  03:00.0 VGA compatible controller: Advanced Micro Devices, Inc.
[INFO] GPU Part 2:  [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c0) (prog-if 00 [VGA controller])
[INFO] GPU Memory:  prefetchable)
[INFO] GPU (from glxinfo):  OpenGL renderer string: AMD Radeon RX 6900 XT (radeonsi, navi21, LLVM 18.1.8, DRM 3.54, 6.6.49-1-lts)
[INFO] GPU (from /sys):  amdgpudrmfb
[INFO] --- Debug Information ---
[INFO] SCRIPT_NAME:  install.sh
[INFO] Current working directory:  /home/ssnow/projects/arch-install
[INFO] Install Script:  /home/ssnow/projects/arch-install/install.sh ([SUCCESS] File/Directory EXISTS)
[INFO] arch_config.toml:  /home/ssnow/projects/arch-install/arch_config.toml ([SUCCESS] File/Directory EXISTS)
[INFO] arch_config.cfg:  /home/ssnow/projects/arch-install/arch_config.cfg ([SUCCESS] File/Directory EXISTS)
[INFO] ARCH_DIR:  /home/ssnow/projects/arch-install ([SUCCESS] File/Directory EXISTS)
[INFO] SCRIPT_DIR:  /home/ssnow/projects/arch-install ([SUCCESS] File/Directory EXISTS)
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg ([SUCCESS] File/Directory EXISTS)
[INFO] SCRIPT_VERSION:  1.0.0
[INFO] DRY_RUN:  true
[INFO] Bash version:  5.2.32(1)-release
[INFO] User running the script:  ssnow
[INFO] --------- Logs -----------
[INFO] LOG_DIR:  /tmp/arch-install-logs ([SUCCESS] File/Directory EXISTS)
[INFO] LOG_FILE:  /tmp/arch-install-logs/arch_install.log ([SUCCESS] File/Directory EXISTS)
[INFO] PROCESS_LOG:  /tmp/arch-install-logs/process.log ([SUCCESS] File/Directory EXISTS)
[INFO] DEBUG_LOG:  /tmp/arch-install-logs/debug.log ([SUCCESS] File/Directory EXISTS)
[INFO] ERROR_LOG:  /tmp/arch-install-logs/error.log ([SUCCESS] File/Directory EXISTS)
[INFO] ---Install config files---
[INFO] Contents of arch_config.toml:
[INFO]     hostname = 'archlinux'
[INFO]     username = 'user'
[INFO]     password = 'changeme'
[INFO]     timezone = 'America/Toronto'
[INFO]     locale = 'en_US.UTF-8'
[INFO]     keyboard_layout = 'us'
[INFO]     keymap = 'en'
[INFO]     package_manager = 'paru'
[INFO]     bootloader = 'grub'
[INFO]     desktop_environment = 'gnome'
[INFO]     reflector_country = 'CA'
[INFO]     microcode = 'amd'
[INFO]     use_luks = false
[INFO]     luks_password = 'changeme'
[INFO]     install_device = 'nvme3n1'
[INFO]     partition1 = '/dev/nvme3n1p1'
[INFO]     partition2 = '/dev/nvme3n1p2'
[INFO]     partition3 = '/dev/nvme3n1p3'
[INFO]     shell = 'bash'
[INFO]     terminal = 'alacritty'
[INFO]     enable_ssh = true
[INFO]     format_type = 'btrfs'
[INFO]     sub_volumes = '@,@home,@var,@tmp,@.snapshots'
[INFO]     subvol_dir = 'boot/efi,home,.snapshots,var/{cache,var/log}'
[INFO]     device_type = 'ssd'
[INFO]     grub_theme = 'CyberRe'
[INFO]     load_themes = true
[INFO]     
[INFO]     
[INFO]     
[INFO]     
[INFO] Contents of arch_config.cfg:
[INFO]     hostname=archlinux
[INFO]     username=user
[INFO]     password=changeme
[INFO]     timezone=America/Toronto
[INFO]     locale=en_US.UTF-8
[INFO]     keyboard_layout=us
[INFO]     keymap=en
[INFO]     package_manager=paru
[INFO]     bootloader=grub
[INFO]     desktop_environment=gnome
[INFO]     reflector_country=CA
[INFO]     microcode=amd
[INFO]     use_luks=false
[INFO]     luks_password=changeme
[INFO]     install_device=nvme3n1
[INFO]     partition1=/dev/nvme3n1p1
[INFO]     partition2=/dev/nvme3n1p2
[INFO]     partition3=/dev/nvme3n1p3
[INFO]     shell=bash
[INFO]     terminal=alacritty
[INFO]     enable_ssh=false
[INFO]     format_type=btrfs
[INFO]     sub_volumes=@,@home,@var,@tmp,@.snapshots
[INFO]     BOOT_DEVICE=/dev/disk/by-partlabel/BOOT
[INFO]     ROOT_DEVICE=/dev/disk/by-partlabel/root
[INFO]     INSTALL_DEVICE=nvme3n1
[INFO]     
[INFO]     
[INFO] ------------------------
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  format_type
[INFO] format_type:  btrfs
[INFO] Loading config for:  desktop_environment
[INFO] desktop_environment:  gnome
[INFO] load_config completed
[OK] Configuration loaded successfully
[INFO] Installation Stages and Scripts:
[INFO]   1-pre: pre-setup.sh run-checks.sh
[INFO]   2-drive: partition-btrfs.sh format-btrfs.sh
[INFO]   3-base: bootstrap-pkgs.sh generate-fstab.sh
[INFO]   4-post: system-conf.sh system-pkgs.sh terminal.sh
[INFO]   5-desktop: gnome.sh
[INFO] Starting stage:  1-pre
[ACTION] Processing script: 1-pre/pre-setup.sh
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Pre-setup (ID: 1726232000)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Pre-setup
------------------------------------------------------------------------

[INFO] Starting pre-setup process
[INFO] DRY_RUN in install.sh is set to: true
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  reflector_country
[INFO] reflector_country:  CA
[INFO] load_config completed
[OK] Configuration loaded successfully
[ACTION] Starting:  Pre-setup Process (Total steps: 6)
[INFO] [1/6]:  Setting system time
[ACTION] [DRY RUN] Would execute:  timedatectl set-ntp true
[INFO] [2/6]:  Updating archlinux-keyring
[ACTION] [DRY RUN] Would execute:  pacman -Sy archlinux-keyring --noconfirm
[INFO] [3/6]:  Installing pre-requisite packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm pacman-contrib terminus-font reflector gptfdisk btrfs-progs glibc
[INFO] [4/6]:  Setting font
[ACTION] [DRY RUN] Would execute:  setfont ter-v22b
[INFO] [5/6]:  Enabling parallel downloads and color in pacman.conf
[ACTION] [DRY RUN] Would execute:  sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf
[INFO] [6/6]:  Synchronizing package databases
[ACTION] [DRY RUN] Would execute:  pacman -Syy
[OK] Pre-setup process completed successfully
[ACTION] Starting:  Mirrors Setup (Total steps: 9)
[INFO] [1/9]:  Setting system time
[ACTION] [DRY RUN] Would execute:  timedatectl set-ntp true
[INFO] [2/9]:  Updating archlinux-keyring
[ACTION] [DRY RUN] Would execute:  pacman -Sy archlinux-keyring --noconfirm
[INFO] [3/9]:  Installing pre-requisite packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm pacman-contrib terminus-font reflector gptfdisk btrfs-progs glibc
[INFO] [4/9]:  Setting font
[ACTION] [DRY RUN] Would execute:  setfont ter-v22b
[INFO] [5/9]:  Enabling parallel downloads and color in pacman.conf
[ACTION] [DRY RUN] Would execute:  sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf
[INFO] [6/9]:  Synchronizing package databases
[ACTION] [DRY RUN] Would execute:  pacman -Syy
[INFO] [7/9]:  Detecting country
[ACTION] [DRY RUN] Would execute:  curl -s 'https://ifconfig.co/country-iso' > CA
[INFO] [8/9]:  Backing up mirrorlist
[ACTION] [DRY RUN] Would execute:  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
[INFO] [9/9]:  Updating mirrors with reflector
[ACTION] [DRY RUN] Would execute:  reflector -a 48 -c "CA" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
[OK] Mirror setup completed successfully
[ACTION] Starting:  Drive Selection (Total steps: 10)
[INFO] [1/10]:  Setting system time
[ACTION] [DRY RUN] Would execute:  timedatectl set-ntp true
[INFO] [2/10]:  Updating archlinux-keyring
[ACTION] [DRY RUN] Would execute:  pacman -Sy archlinux-keyring --noconfirm
[INFO] [3/10]:  Installing pre-requisite packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm pacman-contrib terminus-font reflector gptfdisk btrfs-progs glibc
[INFO] [4/10]:  Setting font
[ACTION] [DRY RUN] Would execute:  setfont ter-v22b
[INFO] [5/10]:  Enabling parallel downloads and color in pacman.conf
[ACTION] [DRY RUN] Would execute:  sed -i -e '/^#ParallelDownloads/s/^#//' -e '/^#Color/s/^#//' /etc/pacman.conf
[INFO] [6/10]:  Synchronizing package databases
[ACTION] [DRY RUN] Would execute:  pacman -Syy
[INFO] [7/10]:  Detecting country
[ACTION] [DRY RUN] Would execute:  curl -s 'https://ifconfig.co/country-iso' > CA
[INFO] [8/10]:  Backing up mirrorlist
[ACTION] [DRY RUN] Would execute:  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
[INFO] [9/10]:  Updating mirrors with reflector
[ACTION] [DRY RUN] Would execute:  reflector -a 48 -c "CA" -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
[INFO] [10/10]:  Selecting installation drive
[ACTION] [DRY RUN] Would execute:  show_drive_list
[OK] Drive selection completed successfully
[OK] Pre-setup process completed successfully
[PROC] Process completed successfully:  Pre-setup (ID: 1726232000)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[ACTION] Processing script: 1-pre/run-checks.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Run Checks (ID: 1726232001)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Run Checks
------------------------------------------------------------------------

[INFO] Starting pre-installation checks
[INFO] Starting pre-installation checks
[INFO] Running Pacstrap Check
[ACTION] [DRY RUN] Would execute: [ -f /usr/bin/pacstrap ]
[OK] Pacstrap Check passed
[INFO] Running Root Check
[ACTION] [DRY RUN] Would execute: root_check
[OK] Root Check passed
[INFO] Running Arch Check
[ACTION] [DRY RUN] Would execute: arch_check
[OK] Arch Check passed
[INFO] Running Pacman Check
[ACTION] [DRY RUN] Would execute: pacman_check
[OK] Pacman Check passed
[INFO] Running Docker Check
[ACTION] [DRY RUN] Would execute: docker_check
[OK] Docker Check passed
[OK] All pre-installation checks passed. Proceeding with installation.
[OK] All pre-installation checks passed. Proceeding with installation.
[PROC] Process completed successfully:  Run Checks (ID: 1726232001)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[INFO] Starting stage:  2-drive
[ACTION] Processing script: 2-drive/partition-btrfs.sh
[INFO] DRY_RUN in install.sh is set to: true
[INFO] DRY_RUN is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  BTRFS Partitioning (ID: 1726232001)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 BTRFS Partitioning
------------------------------------------------------------------------

[INFO] Starting BTRFS partitioning
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  INSTALL_DEVICE
[INFO] INSTALL_DEVICE:  nvme3n1
[INFO] Loading config for:  use_luks
[INFO] use_luks:  false
[INFO] load_config completed
[OK] Configuration loaded successfully
[INFO] Partitioning nvme3n1 for BTRFS
[ACTION] Starting:  Partition Disk for BTRFS (Total steps: 5)
[INFO] [1/5]:  Zapping and creating new GPT on nvme3n1
[ACTION] [DRY RUN] Would execute:  sgdisk -Z nvme3n1 -a 2048 -o nvme3n1
[INFO] [2/5]:  Creating BIOS boot partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n1::+1M    -t1:ef02 -c1:BIOSBOOT nvme3n1
[INFO] [3/5]:  Creating EFI boot partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n2:0:+1024M -t2:ef00 -c2:EFIBOOT nvme3n1
[INFO] [4/5]:  Creating root partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n3:0:0     -t3:8300 -c3:ROOT nvme3n1
[INFO] [5/5]:  Probing partitions
[ACTION] [DRY RUN] Would execute:  partprobe -s nvme3n1
[OK] Partitioning disk completed successfully
[ACTION] Starting:  Set Device Options (Total steps: 12)
[INFO] [1/12]:  Zapping and creating new GPT on nvme3n1
[ACTION] [DRY RUN] Would execute:  sgdisk -Z nvme3n1 -a 2048 -o nvme3n1
[INFO] [2/12]:  Creating BIOS boot partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n1::+1M    -t1:ef02 -c1:BIOSBOOT nvme3n1
[INFO] [3/12]:  Creating EFI boot partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n2:0:+1024M -t2:ef00 -c2:EFIBOOT nvme3n1
[INFO] [4/12]:  Creating root partition
[ACTION] [DRY RUN] Would execute:  sgdisk -n3:0:0     -t3:8300 -c3:ROOT nvme3n1
[INFO] [5/12]:  Probing partitions
[ACTION] [DRY RUN] Would execute:  partprobe -s nvme3n1
[INFO] [6/12]:  Setting BOOT_DEVICE
[ACTION] [DRY RUN] Would execute:  set_option BOOT_DEVICE "/dev/disk/by-partlabel/BOOT"
[INFO] [7/12]:  Setting EFI_DEVICE
[ACTION] [DRY RUN] Would execute:  set_option EFI_DEVICE "/dev/disk/by-partlabel/EFIBOOT"
[INFO] [8/12]:  Setting BIOS_DEVICE
[ACTION] [DRY RUN] Would execute:  set_option BIOS_DEVICE "/dev/disk/by-partlabel/BIOSBOOT"
[INFO] [9/12]:  Setting partition1
[ACTION] [DRY RUN] Would execute:  set_option partition1 "nvme3n1p1"
[INFO] [10/12]:  Setting partition2
[ACTION] [DRY RUN] Would execute:  set_option partition2 "nvme3n1p2"
[INFO] [11/12]:  Setting partition3
[ACTION] [DRY RUN] Would execute:  set_option partition3 "nvme3n1p3"
[INFO] [12/12]:  Setting ROOT_DEVICE
[ACTION] [DRY RUN] Would execute:  set_option ROOT_DEVICE "/dev/disk/by-partlabel/root"
[OK] Setting device options completed successfully
[OK] BTRFS partitioning completed successfully
[PROC] Process completed successfully:  BTRFS Partitioning (ID: 1726232001)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[ACTION] Processing script: 2-drive/format-btrfs.sh
[INFO] DRY_RUN in install.sh is set to: true
[INFO] DRY_RUN is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  BTRFS Formatting (ID: 1726232001)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 BTRFS Formatting
------------------------------------------------------------------------

[INFO] Starting BTRFS formatting and setup
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  partition2
[INFO] partition2:  /dev/nvme3n1p2
[INFO] Loading config for:  partition3
[INFO] partition3:  /dev/nvme3n1p3
[INFO] Loading config for:  use_luks
[INFO] use_luks:  false
[INFO] Loading config for:  luks_password
[INFO] luks_password:  changeme
[INFO] Loading config for:  ROOT_DEVICE
[INFO] ROOT_DEVICE:  /dev/disk/by-partlabel/root
[INFO] Loading config for:  BOOT_DEVICE
[INFO] BOOT_DEVICE:  /dev/disk/by-partlabel/BOOT
[INFO] load_config completed
[OK] Configuration loaded successfully
[INFO] Loaded values:
[INFO] partition2: /dev/nvme3n1p2
[INFO] partition3: /dev/nvme3n1p3
[INFO] use_luks: false
[INFO] luks_password: changeme
[INFO] ROOT_DEVICE: /dev/disk/by-partlabel/root
[ACTION] Starting:  Format Partitions for BTRFS (Total steps: 2)
[INFO] [1/2]:  Formatting EFI partition
[ACTION] [DRY RUN] Would execute:  mkfs.vfat -F32 -n EFIBOOT /dev/disk/by-partlabel/BOOT
[INFO] [2/2]:  Formatting ROOT partition with BTRFS
[ACTION] [DRY RUN] Would execute:  mkfs.btrfs -f -L ROOT /dev/disk/by-partlabel/root
[OK] Formatting partitions completed successfully
[ACTION] Starting:  Create BTRFS Subvolumes (Total steps: 9)
[INFO] [1/9]:  Formatting EFI partition
[ACTION] [DRY RUN] Would execute:  mkfs.vfat -F32 -n EFIBOOT /dev/disk/by-partlabel/BOOT
[INFO] [2/9]:  Formatting ROOT partition with BTRFS
[ACTION] [DRY RUN] Would execute:  mkfs.btrfs -f -L ROOT /dev/disk/by-partlabel/root
[INFO] [3/9]:  Mounting ROOT device
[ACTION] [DRY RUN] Would execute:  mount /dev/disk/by-partlabel/root /mnt
[INFO] [4/9]:  Creating @ subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@
[INFO] [5/9]:  Creating @home subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@home
[INFO] [6/9]:  Creating @var subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@var
[INFO] [7/9]:  Creating @tmp subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@tmp
[INFO] [8/9]:  Creating @.snapshots subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@.snapshots
[INFO] [9/9]:  Unmounting ROOT device
[ACTION] [DRY RUN] Would execute:  umount /mnt
[OK] Creating BTRFS subvolumes completed successfully
[ACTION] Starting:  Mount BTRFS Subvolumes (Total steps: 17)
[INFO] [1/17]:  Formatting EFI partition
[ACTION] [DRY RUN] Would execute:  mkfs.vfat -F32 -n EFIBOOT /dev/disk/by-partlabel/BOOT
[INFO] [2/17]:  Formatting ROOT partition with BTRFS
[ACTION] [DRY RUN] Would execute:  mkfs.btrfs -f -L ROOT /dev/disk/by-partlabel/root
[INFO] [3/17]:  Mounting ROOT device
[ACTION] [DRY RUN] Would execute:  mount /dev/disk/by-partlabel/root /mnt
[INFO] [4/17]:  Creating @ subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@
[INFO] [5/17]:  Creating @home subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@home
[INFO] [6/17]:  Creating @var subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@var
[INFO] [7/17]:  Creating @tmp subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@tmp
[INFO] [8/17]:  Creating @.snapshots subvolume
[ACTION] [DRY RUN] Would execute:  btrfs subvolume create /mnt/@.snapshots
[INFO] [9/17]:  Unmounting ROOT device
[ACTION] [DRY RUN] Would execute:  umount /mnt
[INFO] [10/17]:  Mounting @ subvolume
[ACTION] [DRY RUN] Would execute:  mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/disk/by-partlabel/root /mnt
[INFO] [11/17]:  Creating mount points
[ACTION] [DRY RUN] Would execute:  mkdir -p /mnt/{home,var,tmp,.snapshots}
[INFO] [12/17]:  Mounting @home subvolume
[ACTION] [DRY RUN] Would execute:  mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/disk/by-partlabel/root /mnt/home
[INFO] [13/17]:  Mounting @var subvolume
[ACTION] [DRY RUN] Would execute:  mount -o noatime,compress=zstd,space_cache=v2,subvol=@var /dev/disk/by-partlabel/root /mnt/var
[INFO] [14/17]:  Mounting @tmp subvolume
[ACTION] [DRY RUN] Would execute:  mount -o noatime,compress=zstd,space_cache=v2,subvol=@tmp /dev/disk/by-partlabel/root /mnt/tmp
[INFO] [15/17]:  Mounting @.snapshots subvolume
[ACTION] [DRY RUN] Would execute:  mount -o noatime,compress=zstd,space_cache=v2,subvol=@.snapshots /dev/disk/by-partlabel/root /mnt/.snapshots
[INFO] [16/17]:  Creating boot directory
[ACTION] [DRY RUN] Would execute:  mkdir -p /mnt/boot
[INFO] [17/17]:  Mounting EFI partition
[ACTION] [DRY RUN] Would execute:  mount /dev/nvme3n1p2 /mnt/boot/
[OK] Mounting BTRFS subvolumes completed successfully
[OK] BTRFS formatting and mounting completed successfully
[PROC] Process completed successfully:  BTRFS Formatting (ID: 1726232001)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[INFO] Starting stage:  3-base
[ACTION] Processing script: 3-base/bootstrap-pkgs.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Bootstrap Packages Installation (ID: 1726232002)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Bootstrap Packages Installation
------------------------------------------------------------------------

[INFO] Starting base package installation
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  microcode
[INFO] microcode:  amd
[INFO] load_config completed
[OK] Configuration loaded successfully
[ACTION] Starting:  Install Base Packages (Total steps: 1)
[INFO] [1/1]:  Installing base packages base base-devel linux-lts linux-lts-headers linux linux-headers linux-firmware amd-ucode efibootmgr
[ACTION] [DRY RUN] Would execute:  pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux linux-headers linux-firmware amd-ucode efibootmgr
[OK] Base packages installed successfully
[OK] Base package installation completed successfully
[PROC] Process completed successfully:  Bootstrap Packages Installation (ID: 1726232002)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[ACTION] Processing script: 3-base/generate-fstab.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Generate fstab (ID: 1726232002)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Generate fstab
------------------------------------------------------------------------

[INFO] Starting fstab generation
[INFO] Backing up fstab
[WARNING] Mount point /mnt is not accessible. Skipping fstab backup.
[ACTION] Starting:  Generate fstab Configuration (Total steps: 2)
[INFO] [1/2]:  Generating new fstab
[ACTION] [DRY RUN] Would execute:  genfstab -U /mnt >> /mnt/etc/fstab
[INFO] [2/2]:  Displaying contents of fstab
[ACTION] [DRY RUN] Would execute:  cat "/mnt/etc/fstab"
[OK] fstab generated successfully
[OK] fstab generation completed successfully
[PROC] Process completed successfully:  Generate fstab (ID: 1726232002)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[INFO] Starting stage:  4-post
[ACTION] Processing script: 4-post/system-conf.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  System Configuration (ID: 1726232002)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 System Configuration
------------------------------------------------------------------------

[INFO] Starting system configuration
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  keymap
[INFO] keymap:  en
[INFO] Loading config for:  locale
[INFO] locale:  en_US.UTF-8
[INFO] Loading config for:  timezone
[INFO] timezone:  America/Toronto
[INFO] Loading config for:  hostname
[INFO] hostname:  archlinux
[INFO] Loading config for:  microcode
[INFO] microcode:  amd
[INFO] Loading config for:  username
[INFO] username:  user
[INFO] Loading config for:  password
[INFO] password:  changeme
[INFO] Loading config for:  use_luks
[INFO] use_luks:  false
[INFO] Loading config for:  luks_password
[INFO] luks_password:  changeme
[INFO] load_config completed
[OK] Configuration loaded successfully
[ACTION] Starting:  Network Setup Configuration (Total steps: 2)
[INFO] [1/2]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/2]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[OK] Network setup completed successfully
[ACTION] Starting:  System Requirements (Total steps: 3)
[INFO] [1/3]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/3]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/3]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[OK] System requirements installed successfully
/home/ssnow/projects/arch-install/scripts/4-post/system-conf.sh: line 84: [: "64954668": integer expression expected
[ACTION] Starting:  Otimize makepkg Configuration (Total steps: 4)
[INFO] [1/4]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/4]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/4]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[INFO] [4/4]:  Optimizing makepkg configuration for 24 cores
[ACTION] [DRY RUN] Would execute:  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j24\"/g" /etc/makepkg.conf
[OK] makepkg optimized successfully
[ACTION] Starting:  System Configuration (Total steps: 16)
[INFO] [1/16]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/16]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/16]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[INFO] [4/16]:  Optimizing makepkg configuration for 24 cores
[ACTION] [DRY RUN] Would execute:  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j24\"/g" /etc/makepkg.conf
[INFO] [5/16]:  Configuring locale
[ACTION] [DRY RUN] Would execute:  sed -i "/^#/s/^#//" /mnt/etc/locale.gen
[INFO] [6/16]:  Generating locale
[ACTION] [DRY RUN] Would execute:  arch-chroot /mnt locale-gen
[INFO] [7/16]:  Setting timezone
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-timezone ""
[INFO] [8/16]:  Enabling NTP
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-ntp 1
[INFO] [9/16]:  Setting system locale
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-locale LANG=""
[INFO] [10/16]:  Configuring localtime
[ACTION] [DRY RUN] Would execute:  ln -sf /usr/share/zoneinfo/"" /etc/localtime
[INFO] [11/16]:  Setting keymap
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-keymap ""
[INFO] [12/16]:  Configuring sudo rights
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [13/16]:  Enabling parallel downloads in pacman
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [14/16]:  Enabling multilib repository
[ACTION] [DRY RUN] Would execute:  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
[INFO] [15/16]:  Updating package databases
[ACTION] [DRY RUN] Would execute:  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
[INFO] [16/16]: 
[ACTION] [DRY RUN] Would execute:  pacman -Sy --noconfirm --needed
[OK] System configured successfully
[ACTION] Starting:  Microcode (Total steps: 17)
[INFO] [1/17]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/17]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/17]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[INFO] [4/17]:  Optimizing makepkg configuration for 24 cores
[ACTION] [DRY RUN] Would execute:  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j24\"/g" /etc/makepkg.conf
[INFO] [5/17]:  Configuring locale
[ACTION] [DRY RUN] Would execute:  sed -i "/^#/s/^#//" /mnt/etc/locale.gen
[INFO] [6/17]:  Generating locale
[ACTION] [DRY RUN] Would execute:  arch-chroot /mnt locale-gen
[INFO] [7/17]:  Setting timezone
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-timezone ""
[INFO] [8/17]:  Enabling NTP
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-ntp 1
[INFO] [9/17]:  Setting system locale
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-locale LANG=""
[INFO] [10/17]:  Configuring localtime
[ACTION] [DRY RUN] Would execute:  ln -sf /usr/share/zoneinfo/"" /etc/localtime
[INFO] [11/17]:  Setting keymap
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-keymap ""
[INFO] [12/17]:  Configuring sudo rights
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [13/17]:  Enabling parallel downloads in pacman
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [14/17]:  Enabling multilib repository
[ACTION] [DRY RUN] Would execute:  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
[INFO] [15/17]:  Updating package databases
[ACTION] [DRY RUN] Would execute:  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
[INFO] [16/17]: 
[ACTION] [DRY RUN] Would execute:  pacman -Sy --noconfirm --needed
[INFO] [17/17]:  Installing AMD microcode
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed amd-ucode
[OK] Microcode installed successfully
[ACTION] Starting:  GPU Driver (Total steps: 18)
[INFO] [1/18]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/18]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/18]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[INFO] [4/18]:  Optimizing makepkg configuration for 24 cores
[ACTION] [DRY RUN] Would execute:  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j24\"/g" /etc/makepkg.conf
[INFO] [5/18]:  Configuring locale
[ACTION] [DRY RUN] Would execute:  sed -i "/^#/s/^#//" /mnt/etc/locale.gen
[INFO] [6/18]:  Generating locale
[ACTION] [DRY RUN] Would execute:  arch-chroot /mnt locale-gen
[INFO] [7/18]:  Setting timezone
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-timezone ""
[INFO] [8/18]:  Enabling NTP
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-ntp 1
[INFO] [9/18]:  Setting system locale
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-locale LANG=""
[INFO] [10/18]:  Configuring localtime
[ACTION] [DRY RUN] Would execute:  ln -sf /usr/share/zoneinfo/"" /etc/localtime
[INFO] [11/18]:  Setting keymap
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-keymap ""
[INFO] [12/18]:  Configuring sudo rights
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [13/18]:  Enabling parallel downloads in pacman
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [14/18]:  Enabling multilib repository
[ACTION] [DRY RUN] Would execute:  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
[INFO] [15/18]:  Updating package databases
[ACTION] [DRY RUN] Would execute:  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
[INFO] [16/18]: 
[ACTION] [DRY RUN] Would execute:  pacman -Sy --noconfirm --needed
[INFO] [17/18]:  Installing AMD microcode
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed amd-ucode
[INFO] [18/18]:  Installing AMD drivers
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed xf86-video-amdgpu
[OK] GPU drivers installed successfully
[ACTION] Starting:  User add Configuration (Total steps: 22)
[INFO] [1/22]:  Installing network packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed networkmanager dhclient
[INFO] [2/22]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [3/22]:  Installing system requirement packages
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed reflector rsync grub arch-install-scripts git ntp wget
[INFO] [4/22]:  Optimizing makepkg configuration for 24 cores
[ACTION] [DRY RUN] Would execute:  sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j24\"/g" /etc/makepkg.conf
[INFO] [5/22]:  Configuring locale
[ACTION] [DRY RUN] Would execute:  sed -i "/^#/s/^#//" /mnt/etc/locale.gen
[INFO] [6/22]:  Generating locale
[ACTION] [DRY RUN] Would execute:  arch-chroot /mnt locale-gen
[INFO] [7/22]:  Setting timezone
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-timezone ""
[INFO] [8/22]:  Enabling NTP
[ACTION] [DRY RUN] Would execute:  timedatectl --no-ask-password set-ntp 1
[INFO] [9/22]:  Setting system locale
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-locale LANG=""
[INFO] [10/22]:  Configuring localtime
[ACTION] [DRY RUN] Would execute:  ln -sf /usr/share/zoneinfo/"" /etc/localtime
[INFO] [11/22]:  Setting keymap
[ACTION] [DRY RUN] Would execute:  localectl --no-ask-password set-keymap ""
[INFO] [12/22]:  Configuring sudo rights
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [13/22]:  Enabling parallel downloads in pacman
[ACTION] [DRY RUN] Would execute:  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
[INFO] [14/22]:  Enabling multilib repository
[ACTION] [DRY RUN] Would execute:  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
[INFO] [15/22]:  Updating package databases
[ACTION] [DRY RUN] Would execute:  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
[INFO] [16/22]: 
[ACTION] [DRY RUN] Would execute:  pacman -Sy --noconfirm --needed
[INFO] [17/22]:  Installing AMD microcode
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed amd-ucode
[INFO] [18/22]:  Installing AMD drivers
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm --needed xf86-video-amdgpu
[INFO] [19/22]:  Creating libvirt group
[ACTION] [DRY RUN] Would execute:  groupadd libvirt
[INFO] [20/22]:  Adding user
[ACTION] [DRY RUN] Would execute:  useradd -m -G wheel,libvirt -s /bin/bash "ssnow"
[INFO] [21/22]:  Setting user password
[ACTION] [DRY RUN] Would execute:  echo "ssnow:" | chpasswd
[INFO] [22/22]:  Setting hostname
[ACTION] [DRY RUN] Would execute:  echo "angryguy" > /etc/hostname
[OK] User added successfully
[OK] System configuration completed successfully
[PROC] Process completed successfully:  System Configuration (ID: 1726232002)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[ACTION] Processing script: 4-post/system-pkgs.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  System Packages (ID: 1726232004)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 System Packages
------------------------------------------------------------------------

[INFO] Starting system packages installation
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] load_config completed
[OK] Configuration loaded successfully
[ACTION] Starting:  Network Setup Configuration (Total steps: 1)
[INFO] [1/1]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[OK] Network setup completed successfully
[INFO] - Installing System Base Packages.
[ACTION] Starting:  System Requirements (Total steps: 28)
[INFO] [1/28]:  Enabling NetworkManager
[ACTION] [DRY RUN] Would execute:  systemctl enable NetworkManager
[INFO] [2/28]:  Installing system package eza
[ACTION] [DRY RUN] Would execute:  install_packages eza
[INFO] [3/28]:  fzf
[ACTION] [DRY RUN] Would execute:  fzf
[INFO] [4/28]:  vim
[ACTION] [DRY RUN] Would execute:  vim
[INFO] [5/28]:  openssh
[ACTION] [DRY RUN] Would execute:  openssh
[INFO] [6/28]:  reflector
[ACTION] [DRY RUN] Would execute:  reflector
[INFO] [7/28]:  rsync
[ACTION] [DRY RUN] Would execute:  rsync
[INFO] [8/28]:  terminus-font
[ACTION] [DRY RUN] Would execute:  terminus-font
[INFO] [9/28]:  opendoas
[ACTION] [DRY RUN] Would execute:  opendoas
[INFO] [10/28]:  git
[ACTION] [DRY RUN] Would execute:  git
[INFO] [11/28]:  fastfetch
[ACTION] [DRY RUN] Would execute:  fastfetch
[INFO] [12/28]:  e2fsprogs
[ACTION] [DRY RUN] Would execute:  e2fsprogs
[INFO] [13/28]:  dosfstools
[ACTION] [DRY RUN] Would execute:  dosfstools
[INFO] [14/28]:  btrfs-progs
[ACTION] [DRY RUN] Would execute:  btrfs-progs
[INFO] [15/28]:  plymouth
[ACTION] [DRY RUN] Would execute:  plymouth
[INFO] [16/28]:  os-prober
[ACTION] [DRY RUN] Would execute:  os-prober
[INFO] [17/28]:  grub
[ACTION] [DRY RUN] Would execute:  grub
[INFO] [18/28]:  networkmanager
[ACTION] [DRY RUN] Would execute:  networkmanager
[INFO] [19/28]:  network-manager-applet
[ACTION] [DRY RUN] Would execute:  network-manager-applet
[INFO] [20/28]:  dhclient
[ACTION] [DRY RUN] Would execute:  dhclient
[INFO] [21/28]:  xdg-user-dirs
[ACTION] [DRY RUN] Would execute:  xdg-user-dirs
[INFO] [22/28]:  pipewire
[ACTION] [DRY RUN] Would execute:  pipewire
[INFO] [23/28]:  wireplumber
[ACTION] [DRY RUN] Would execute:  wireplumber
[INFO] [24/28]:  pipewire-pulse
[ACTION] [DRY RUN] Would execute:  pipewire-pulse
[INFO] [25/28]:  pipewire-alsa
[ACTION] [DRY RUN] Would execute:  pipewire-alsa
[INFO] [26/28]:  pipewire-jack
[ACTION] [DRY RUN] Would execute:  pipewire-jack
[INFO] [27/28]:  bluez
[ACTION] [DRY RUN] Would execute:  bluez
[INFO] [28/28]:  bluez-utils
[ACTION] [DRY RUN] Would execute:  bluez-utils
[OK] System requirements installed successfully
[OK] System packages installation completed successfully
[PROC] Process completed successfully:  System Packages (ID: 1726232004)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[ACTION] Processing script: 4-post/terminal.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  Terminal Configuration (ID: 1726232005)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 Terminal Configuration
------------------------------------------------------------------------

[INFO] Starting terminal configuration
[INFO] Starting load_config function
[INFO] CONFIG_FILE:  /home/ssnow/projects/arch-install/arch_config.cfg
[INFO] Loading config for:  shell
[INFO] shell:  bash
[INFO] load_config completed
[OK] Configuration loaded successfully
[INFO] Installing and Configuring Shell: bash
[ACTION] Starting:  Install Shell Configuration (Total steps: 1)
[INFO] [1/1]:  Installing bash and related packages
[ACTION] [DRY RUN] Would execute:  pacman -S --needed --noconfirm bash bash-completion bash-syntax-highlighting
[OK] Shell installed successfully
[OK] Done. bash shell is now installed and configured.
[PROC] Process completed successfully:  Terminal Configuration (ID: 1726232005)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[INFO] Starting stage:  5-desktop
[ACTION] Processing script: 5-desktop/gnome.sh
[INFO] DRY_RUN in install.sh is set to: true
[OK] Log files set up in /tmp/arch-install-logs
[INFO] Log files initialized in  /tmp/arch-install-logs
[PROC] Starting process:  GNOME Installation (ID: 1726232005)
 
-------------------------------------------------------------------------

                 █████╗ ██████╗  ██████ ██╗  ██╗
                ██╔══██╗██╔══██╗██╔════╝██║  ██║
                ███████║██████╔╝██║     ███████║ 
                ██╔══██║██╔══██╗██║     ██╔══██║
                ██║  ██║██║  ██║╚██████╗██║  ██║
                ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
------------------------------------------------------------------------
                 GNOME Installation
------------------------------------------------------------------------

[INFO] Starting GNOME installation
[ACTION] Starting:  Install GNOME Core (Total steps: 9)
[INFO] [1/9]:  Installing gnome
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome
[INFO] [2/9]:  Installing gnome-tweaks
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-tweaks
[INFO] [3/9]:  Installing gnome-terminal
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-terminal
[INFO] [4/9]:  Installing gdm
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gdm
[INFO] [5/9]:  Installing gnome-shell-extensions
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-shell-extensions
[INFO] [6/9]:  Installing gnome-keyring
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-keyring
[INFO] [7/9]:  Installing networkmanager
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm networkmanager
[INFO] [8/9]:  Installing network-manager-applet
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm network-manager-applet
[INFO] [9/9]:  Enabling GDM service
[ACTION] [DRY RUN] Would execute:  systemctl enable gdm.service
[OK] GNOME core installed successfully
[INFO] Available GNOME features:
[INFO] [0] gnome-backgrounds
[INFO] [1] gnome-calendar
[INFO] [2] gnome-clocks
[INFO] [3] gnome-contacts
[INFO] [4] gnome-maps
[INFO] [5] gnome-music
[INFO] [6] gnome-photos
[INFO] [7] gnome-weather
[INFO] [8] gnome-boxes
[INFO] [9] gnome-characters
[INFO] [10] gnome-connections
[INFO] [11] gnome-documents
[INFO] [12] gnome-games
[INFO] [13] gnome-remote-desktop
[INFO] [14] gnome-user-share
[INFO] [15] gnome-video-effects
Enter the numbers of the features you want to install (space-separated), or 'all' for all features: 
[ACTION] Starting:  Install GNOME Features (Total steps: 9)
[INFO] [1/9]:  Installing gnome
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome
[INFO] [2/9]:  Installing gnome-tweaks
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-tweaks
[INFO] [3/9]:  Installing gnome-terminal
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-terminal
[INFO] [4/9]:  Installing gdm
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gdm
[INFO] [5/9]:  Installing gnome-shell-extensions
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-shell-extensions
[INFO] [6/9]:  Installing gnome-keyring
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm gnome-keyring
[INFO] [7/9]:  Installing networkmanager
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm networkmanager
[INFO] [8/9]:  Installing network-manager-applet
[ACTION] [DRY RUN] Would execute:  pacman -S --noconfirm network-manager-applet
[INFO] [9/9]:  Enabling GDM service
[ACTION] [DRY RUN] Would execute:  systemctl enable gdm.service
[OK] GNOME features installed successfully
[OK] GNOME installation completed successfully
[PROC] Process completed successfully:  GNOME Installation (ID: 1726232005)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully
[OK] Installation completed successfully
[OK] Arch Linux installation completed successfully
[PROC] Process completed successfully:  Main Installation Process (ID: 1726232000)
[INFO] Exit handler called with exit code:  0
[INFO] Script execution completed successfully

```