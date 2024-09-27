# File structure
# -----------------------------------

```
arch-install/
├── quick-dirty.sh
├── install.sh
├── Makefile
├── README.md
├── LICENSE
├── arch_config.toml
├── arch_config.cfg
│   ├── config
│   └──
├── lib/
│   ├── lib.sh
├── tools/
│   ├── package_manager
│   └── recovery
└── scripts/
    ├── 1-pre/
    │   ├── run-checks.sh
    │   └── pre-setup.sh
    ├── 2-drive/
    │   ├── partition-${format_type}.sh
    │   └── format-${format_type}.sh
    ├── 3-base/
    │   ├── bootstrap-pkgs.sh
    │   └── generate-fstab.sh
    ├── 4-post/
    │   ├── 
    │   ├── 
    │   └── services
    ├── 5-desktop/
    │   ├──  gnome
    │   ├──  kde
    │   ├──  cosmic
    │   └── dwm
    ├── 6-final
    │   ├── last-cleanup.sh
    │   └── 
    └── 7-post
        ├── post-setup.sh
        └── 
```
# ----------------------------------

# Arch-install
This project is to create a base frame work, whit error handling, checking. it also give the user feedback on the ongoing process of the installation whit messages, print_message INFO "arch installation" and other variasion of this like:
INFO, ERROR, WARNING, DEBUG, OK, PROC.
The print_message() also handle the log() function which pipes this all into a log for later use, or debugging.
it is also designed in a way the colors can be used to highlights part of the messages [INFO] and variables.
this install also has some flags:
1. --dry-run to run the install in test mode whit running any commands but posting what they are, what it would do.
2. --verbose is for more verbose logging for debugging and seeing debug messages.

## Install.sh

1. Install.sh is the base of the project every thing is run from here every thing is started and initialized from here, 
    process_init starts the process. 
    Then the parse_stages_toml() is run to check and organize the stages/scripts of the project to run.
    some of the script are manadatory and some are optional, the manadatory scripts should always run and can not proceed whit out them, 
    on the ohter hand even if optional scripts are missing just post a warning and continue.
    But if the optional script exist process and run it also.
    The project is divided into stages which each stages has its own scripts to run once done it moves to the next stages and repeats.
    it is very important that the script run in their designated order.

2. The configuration file is loaded to populate all the needed variables for the installation to run load_config().
3. The read_config() read the arch_config.toml and copied that inforamation over to the working files arch_config.cfg this file is also 
    used to save other variable that come up and are needed through out the install whit the set_option() function:
    set_option key value pairs.
4. check_required_script() this check that all the necessary scripts are present, or it throws and errors for mandatory scripts.
5. run_install_scripts() -- run_install_scripts "$FORMAT_TYPE" "$DESKTOP_ENVIRONMENT" "$DRY_RUN"
    this will be the main heart of the install.sh this will process all the stages/scripts each script will be executed one by one
    starting at stage 1-pre and scripts run-checks.sh and pre-setup.sh
    here is will take the proceesed stage/scripts replace the placeholder for any script that have varibles like FORMAT_TYPE,
    which give the user the option of partition-{FORMAT_TYPE}.sh to either BTRFS or ext4, the other one is {DESKTOP_ENVIRONMENT}.sh
    so the user can choice the desktop they want none,gonme,kde,cosmic,dwm. 
    here if present the optional script shall be executed, all manadatory script will be executed and processed.
    the scripts get proceesed by execute_script() -- execute_script "$stage_name" "$script"

6. execute_script() here it will check for the dry-run=true flag and simulate the scripts print_message 
    ACTION "[DRY RUN] Would execute:$line".
    If not in dry-run mode then are scripts will be run in live mode bash "$script_path".

## The scripts

1. Each script wil have it's own main and function() to run, each function will have it own steps or commands to execute.
```
    execute_process "process name"
        --debug \
        --error-message "some error" \
        --success-message "step complete" \
        --critcal \
        "some commands to run" \
        "some other command
```
2. pending on the mode dry-run or live all of the commands will be processed also here is where the --use-chroot flag can be 
    used when necessary arch-chroot /mnt /bin/bash -c "$cmd"
    If it just a noraml live command then eval "$cmd" will be used.
    the --critical flag can be used on part that must succeed for the install to be done correctly. it will exit if there is an 
    critical error other wise whit out this flag the script will just give a warning and continue.
3. Each function or steps that have been divided will all be prosessed one by one, in the main() which has it own error handling and checking
    and will trap and display the error if it occurs. once done it will move on the next script or next stage if all the scripts have completeded.


## lib.sh

1. the lib.sh is the holding area for all the common function in the back end needed to make this install posible. The Library.
    here all the variables and logs ect.. will be declared.
    list of function:
```
    show_logo()
    log()
    print_message()
    verbose_print()
    print_system_info()
    process_init()
    process_end()
    setup_error_handling()
    error_handler()
    exit_handler()
    cleanup_handler()
    trap_error()
    trap_exit()
    cleanup()
    load_config()
    get_config_value()
    read_config()
    set_option()
    drive_list()
    show_dirve_list()
    execute_process()
    execute_script()
    run_install_script()
    replace_placeholder()
    should_run_optionqal_script()
    parse_stages_toml()
    backup_config()
    backup_fstab()
    handle_critical_error()
    check_disk_space()
    ensure_log_directory()
    check_required_script()
    check_internet_ connection()
    ask_passwords()
    ask_password()
    configure_network()
    fact_common()
    init_log_trace()
    init_log_file()
```
## Stages
```
1-pre
    -run-checks.sh
    -pre-seetup.sh
2-drive
    -partition-btrfs.sh
    -format-btrfs.sh
    -partition-ext4.sh
    -foramt-ext4.sh
3-base
    -bootloader.sh
    -bootstrap-pkgs.sh
    -generate-fstab.sh
4-post
    -system-config.sh
    -system-pkgs.sh
    -terminal.sh
5-desktop
    -none.sh
    -gnome.sh
    -kde.sh
    -cosmic.sh
    -dwm.sh
6-final
    -last-cleanup.sh
7-post-setup
    -post-setup.sh
```



