#!/usr/bin/env bash

# xfreerdp3-gui.sh - A simple Zenity GUI for FreeRDP v3.x
# Adapted from the original by wyllianbs for FreeRDP legacy versions.
# FreeRDP v3 Documentation: https://github.com/awakecoding/FreeRDP-Manuals/blob/master/User/FreeRDP-User-Manual.markdown

# Configuration
CONF_DIR="$HOME/.config/xfreerdp3-gui"
CONF_FILE="$CONF_DIR/xfreerdp3-gui.conf" # Name|Host|User|Pass|Domain|Resolution|Fullscreen|Sound|DriveName|DrivePath
LOG_FILE="$CONF_DIR/xfreerdp3-gui.log"

# Ensure configuration directory exists
mkdir -p "$CONF_DIR"
touch "$LOG_FILE" # Ensure log file exists

# --- Logging Function ---
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# --- Dependency Check ---
check_deps() {
    for cmd in xfreerdp3 zenity; do
        if ! command -v "$cmd" &>/dev/null; then
            zenity --error --text="Error: '$cmd' command not found. Please install it." --width=300
            log_message "Error: Dependency '$cmd' not found."
            exit 1
        fi
    done
    # Check xfreerdp3 version (basic check for v3.x or higher)
    if ! xfreerdp3 --version | grep -qE "version (3\.|[4-9]\.)"; then
         zenity --warning --text="Warning: This script is intended for FreeRDP v3.x or newer. Your version might be older. Some options may not work as expected." --width=400
         log_message "Warning: xfreerdp3 version might not be v3.x or newer."
    fi
}

# --- Load Connections ---
declare -a connections
load_connections() {
    connections=()
    if [[ -f "$CONF_FILE" ]]; then
        while IFS='|' read -r name host user pass domain resolution fullscreen sound drivename drivepath || [[ -n "$name" ]]; do
            # Handle empty lines or lines with only a name (if any)
            [[ -z "$name" ]] && continue
            connections+=("$name|$host|$user|$pass|$domain|$resolution|$fullscreen|$sound|$drivename|$drivepath")
        done < "$CONF_FILE"
    fi
    log_message "Connections loaded. Count: ${#connections[@]}"
}

# --- Save Connections ---
save_connections() {
    printf "%s\n" "${connections[@]}" > "$CONF_FILE"
    log_message "Connections saved."
}

# --- Add New Connection ---
add_connection() {
    local data
    data=$(zenity --forms --title="Add New RDP Connection" --text="Enter connection details:" \
        --add-entry="Connection Name:" \
        --add-entry="Hostname or IP:" \
        --add-entry="Username (optional):" \
        --add-password="Password (optional, or 'ASK'):" \
        --add-entry="Domain (optional):" \
        --add-combo="Resolution:" --combo-values="Default|1024x768|1280x720|1280x800|1280x1024|1366x768|1440x900|1600x900|1680x1050|1920x1080|1920x1200|Custom" \
        --add-combo="Fullscreen:" --combo-values="No|Yes" \
        --add-combo="Sound:" --combo-values="No|Yes" \
        --add-entry="Share Drive Name (e.g., myshare, optional):" \
        --add-entry="Share Drive Path (e.g., /home/user/shared, optional):" \
        --separator="|" --width=500 --height=450)

    if [[ $? -eq 0 ]] && [[ -n "$data" ]]; then
        local name host user pass domain resolution fullscreen sound drivename drivepath
        IFS='|' read -r name host user pass domain resolution fullscreen sound drivename drivepath <<< "$data"

        if [[ "$resolution" == "Custom" ]]; then
            custom_res=$(zenity --entry --title="Custom Resolution" --text="Enter custom resolution (e.g., 1360x768):")
            if [[ $? -eq 0 ]] && [[ "$custom_res" =~ ^[0-9]+x[0-9]+$ ]]; then
                resolution="$custom_res"
            else
                resolution="Default" # Fallback if custom is cancelled or invalid
            fi
        fi
        
        if [[ -z "$name" ]] || [[ -z "$host" ]]; then
            zenity --error --text="Connection Name and Hostname cannot be empty."
            log_message "Error: Attempted to add connection with empty name or host."
            return
        fi

        connections+=("$name|$host|$user|$pass|$domain|$resolution|$fullscreen|$sound|$drivename|$drivepath")
        save_connections
        log_message "Added connection: $name"
        zenity --info --text="Connection '$name' added successfully."
    else
        log_message "Add connection cancelled."
    fi
}

# --- Edit Connection ---
edit_connection() {
    if [[ ${#connections[@]} -eq 0 ]]; then
        zenity --info --text="No connections to edit."
        log_message "Edit connection: No connections available."
        return
    fi

    local options=()
    for ((i=0; i<${#connections[@]}; i++)); do
        IFS='|' read -r name _ <<< "${connections[$i]}"
        options+=("$((i+1))" "$name")
    done

    local choice
    choice=$(zenity --list --title="Edit Connection" --text="Select a connection to edit:" \
        --column="Index" --column="Name" "${options[@]}" --width=400 --height=300)

    if [[ $? -eq 0 ]] && [[ -n "$choice" ]]; then
        local index=$((choice-1))
        IFS='|' read -r o_name o_host o_user o_pass o_domain o_resolution o_fullscreen o_sound o_drivename o_drivepath <<< "${connections[$index]}"

        local data
        data=$(zenity --forms --title="Edit RDP Connection: $o_name" --text="Modify connection details:" \
            --add-entry="Connection Name:" "$o_name" \
            --add-entry="Hostname or IP:" "$o_host" \
            --add-entry="Username (optional):" "$o_user" \
            --add-password="Password (optional, or 'ASK'):" "$o_pass" \
            --add-entry="Domain (optional):" "$o_domain" \
            --add-combo="Resolution:" --combo-values="Default|1024x768|1280x720|1280x800|1280x1024|1366x768|1440x900|1600x900|1680x1050|1920x1080|1920x1200|$o_resolution|Custom" \
            --add-combo="Fullscreen:" --combo-values="No|Yes|$o_fullscreen" \
            --add-combo="Sound:" --combo-values="No|Yes|$o_sound" \
            --add-entry="Share Drive Name (e.g., myshare, optional):" "$o_drivename" \
            --add-entry="Share Drive Path (e.g., /home/user/shared, optional):" "$o_drivepath" \
            --separator="|" --width=500 --height=450)
        
        if [[ $? -eq 0 ]] && [[ -n "$data" ]]; then
            local name host user pass domain resolution fullscreen sound drivename drivepath
            IFS='|' read -r name host user pass domain resolution fullscreen sound drivename drivepath <<< "$data"

            if [[ "$resolution" == "Custom" ]]; then
                custom_res=$(zenity --entry --title="Custom Resolution" --text="Enter custom resolution (e.g., 1360x768):" --entry-text="$o_resolution")
                if [[ $? -eq 0 ]] && [[ "$custom_res" =~ ^[0-9]+x[0-9]+$ ]]; then
                    resolution="$custom_res"
                else
                    resolution="$o_resolution" # Fallback to original if custom is cancelled or invalid
                fi
            fi

            if [[ -z "$name" ]] || [[ -z "$host" ]]; then
                zenity --error --text="Connection Name and Hostname cannot be empty."
                log_message "Error: Attempted to edit connection with empty name or host."
                return
            fi

            connections[$index]="$name|$host|$user|$pass|$domain|$resolution|$fullscreen|$sound|$drivename|$drivepath"
            save_connections
            log_message "Edited connection: $name (Index: $index)"
            zenity --info --text="Connection '$name' updated successfully."
        else
            log_message "Edit connection cancelled for $o_name."
        fi
    else
        log_message "Edit connection selection cancelled."
    fi
}

# --- Delete Connection ---
delete_connection() {
    if [[ ${#connections[@]} -eq 0 ]]; then
        zenity --info --text="No connections to delete."
        log_message "Delete connection: No connections available."
        return
    fi

    local options=()
    for ((i=0; i<${#connections[@]}; i++)); do
        IFS='|' read -r name _ <<< "${connections[$i]}"
        options+=("$((i+1))" "$name")
    done

    local choice
    choice=$(zenity --list --title="Delete Connection" --text="Select a connection to delete:" \
        --column="Index" --column="Name" "${options[@]}" --width=400 --height=300)

    if [[ $? -eq 0 ]] && [[ -n "$choice" ]]; then
        local index=$((choice-1))
        IFS='|' read -r name_to_delete _ <<< "${connections[$index]}"
        if zenity --question --text="Are you sure you want to delete '$name_to_delete'?" --width=300; then
            unset 'connections[index]'
            connections=("${connections[@]}") # Re-index array
            save_connections
            log_message "Deleted connection: $name_to_delete"
            zenity --info --text="Connection '$name_to_delete' deleted."
        else
            log_message "Deletion cancelled for $name_to_delete."
        fi
    else
        log_message "Delete connection selection cancelled."
    fi
}

# --- Connect to Server ---
connect_to_server() {
    local C_NAME C_HOST C_USER C_PASS C_DOMAIN C_RESOLUTION C_FULLSCREEN C_SOUND C_DRIVENAME C_DRIVEPATH
    IFS='|' read -r C_NAME C_HOST C_USER C_PASS C_DOMAIN C_RESOLUTION C_FULLSCREEN C_SOUND C_DRIVENAME C_DRIVEPATH <<< "$1"

    local XFREERDP_CMD_ARGS=()

    # Server
    XFREERDP_CMD_ARGS+=("/v:$C_HOST")

    # Credentials
    if [[ -n "$C_USER" ]]; then
        XFREERDP_CMD_ARGS+=("/u:$C_USER")
    fi

    if [[ "$C_PASS" == "ASK" ]] || ([[ -z "$C_PASS" ]] && [[ -n "$C_USER" ]]); then
        # Prompt for password if 'ASK' or if username is given but password is not
        local prompted_pass
        prompted_pass=$(zenity --password --title="Password for $C_USER@$C_HOST" --text="Enter password:")
        if [[ $? -ne 0 ]]; then
            log_message "Password prompt cancelled for $C_NAME."
            return # User cancelled password prompt
        fi
        # Only add /p if password was actually entered. Empty password might be valid for some configs.
        [[ -n "$prompted_pass" ]] && XFREERDP_CMD_ARGS+=("/p:$prompted_pass")
    elif [[ -n "$C_PASS" ]]; then
        XFREERDP_CMD_ARGS+=("/p:$C_PASS")
    fi
    
    if [[ -n "$C_DOMAIN" ]]; then
        XFREERDP_CMD_ARGS+=("/d:$C_DOMAIN")
    fi

    # Display
    if [[ "$C_FULLSCREEN" == "Yes" ]]; then
        XFREERDP_CMD_ARGS+=("/f")
    elif [[ "$C_RESOLUTION" != "Default" ]] && [[ -n "$C_RESOLUTION" ]]; then
        XFREERDP_CMD_ARGS+=("/size:$C_RESOLUTION")
    fi

    # Sound
    if [[ "$C_SOUND" == "Yes" ]]; then
        XFREERDP_CMD_ARGS+=("/sound") # Enables sound redirection to client (default mode)
        # Or more explicitly: XFREERDP_CMD_ARGS+=("/sound /audio-mode:1")
    fi

    # Drive Sharing
    if [[ -n "$C_DRIVENAME" ]] && [[ -n "$C_DRIVEPATH" ]]; then
        if [[ -d "$C_DRIVEPATH" ]]; then
            XFREERDP_CMD_ARGS+=("/drive:$C_DRIVENAME,$C_DRIVEPATH")
        else
            zenity --warning --text="Warning for '$C_NAME': Shared drive path '$C_DRIVEPATH' does not exist. Drive will not be shared." --width=400
            log_message "Warning for '$C_NAME': Shared drive path '$C_DRIVEPATH' does not exist."
        fi
    fi

    # Common useful options for FreeRDP v3
    XFREERDP_CMD_ARGS+=("/network:auto")   # Auto-detect network settings
    XFREERDP_CMD_ARGS+=("/clipboard")      # Enable clipboard redirection
    XFREERDP_CMD_ARGS+=("/fonts")          # Enable font smoothing
    #XFREERDP_CMD_ARGS+=("+auth-only")      # Disable NLA if creds are fully provided, if not it prompts. Can be useful.
                                          # Or consider /sec:nla,tls,rdp for explicit security protocol order.
    # XFREERDP_CMD_ARGS+=("/cert:tofu")    # Trust On First Use for certificates. Use with caution.
                                          # Or /cert:ignore (less secure)
    XFREERDP_CMD_ARGS+=("/dynamic-resolution") # If server supports it

    local full_command="xfreerdp3 ${XFREERDP_CMD_ARGS[*]}"
    log_message "Executing: $full_command"
    zenity --info --text="Connecting to '$C_NAME'...\nCommand: $full_command\n\nCheck terminal or log file for details." --timeout=5 --width=500 &
    
    # Using eval to correctly handle passwords with special characters if any, though prompting is safer.
    # Using setsid to detach the xfreerdp3 process from the script's terminal.
    # Nohup might also be considered if you close the terminal launching the script.
    setsid sh -c "eval exec '$full_command'" > "$LOG_FILE.xfreerdp3.$$" 2>&1 &
    # A simpler alternative if no special chars in password and you want output in same terminal
    # eval "$full_command" &
}


# --- Quick Connect ---
quick_connect() {
    local data
    data=$(zenity --forms --title="Quick Connect" --text="Enter RDP Server Details:" \
        --add-entry="Hostname or IP:" \
        --add-entry="Username (optional):" \
        --add-password="Password (optional, or 'ASK'):" \
        --add-entry="Domain (optional):" \
        --add-combo="Resolution:" --combo-values="Default|1024x768|1280x720|1280x800|1280x1024|1366x768|1440x900|1600x900|1680x1050|1920x1080|1920x1200|Custom" \
        --add-combo="Fullscreen:" --combo-values="No|Yes" \
        --add-combo="Sound:" --combo-values="No|Yes" \
        --separator="|" --width=500 --height=400)

    if [[ $? -eq 0 ]] && [[ -n "$data" ]]; then
        local host user pass domain resolution fullscreen sound
        IFS='|' read -r host user pass domain resolution fullscreen sound <<< "$data"

        if [[ "$resolution" == "Custom" ]]; then
            custom_res=$(zenity --entry --title="Custom Resolution" --text="Enter custom resolution (e.g., 1360x768):")
            if [[ $? -eq 0 ]] && [[ "$custom_res" =~ ^[0-9]+x[0-9]+$ ]]; then
                resolution="$custom_res"
            else
                resolution="Default"
            fi
        fi
        
        if [[ -z "$host" ]]; then
            zenity --error --text="Hostname cannot be empty for Quick Connect."
            log_message "Error: Quick Connect attempted with empty host."
            return
        fi
        # For quick connect, drive sharing is omitted for simplicity, but could be added.
        connect_to_server "QuickConnect|$host|$user|$pass|$domain|$resolution|$fullscreen|$sound||"
    else
        log_message "Quick Connect cancelled."
    fi
}


# --- Main Menu ---
main_menu() {
    load_connections

    local main_options=()
    if [[ ${#connections[@]} -gt 0 ]]; then
        main_options+=("Connect to Saved Server")
        for conn_details in "${connections[@]}"; do
            IFS='|' read -r name _ <<< "$conn_details"
            main_options+=("$name")
        done
        main_options+=("---") # Separator
    fi
    main_options+=("Quick Connect" "Add New Connection" "Edit Connection" "Delete Connection" "View Log" "Exit")

    while true; do
        local choice
        choice=$(zenity --list --title="xfreerdp3-gui for FreeRDP v3" \
            --text="Select an action or a saved connection:" \
            --column="Actions / Connections" "${main_options[@]}" \
            --width=450 --height=$(( 200 + ${#connections[@]} * 20 ))) # Dynamic height

        if [[ $? -ne 0 ]] || [[ "$choice" == "Exit" ]]; then
            log_message "Exiting application."
            break
        fi

        case "$choice" in
            "Quick Connect")
                quick_connect
                ;;
            "Add New Connection")
                add_connection
                load_connections # Reload for main menu display
                main_menu # Restart main menu to show new connection
                return # Exit current main_menu instance
                ;;
            "Edit Connection")
                edit_connection
                load_connections # Reload for main menu display
                main_menu # Restart main menu to show changes
                return # Exit current main_menu instance
                ;;
            "Delete Connection")
                delete_connection
                load_connections # Reload for main menu display
                main_menu # Restart main menu to reflect deletion
                return # Exit current main_menu instance
                ;;
            "View Log")
                zenity --text-info --title="Log File Viewer" --filename="$LOG_FILE" --editable --width=800 --height=600
                ;;
            "---")
                # Do nothing for separator
                ;;
            "Connect to Saved Server")
                # This is just a header, do nothing
                ;;
            *)
                # Attempt to connect to a saved server
                local found=0
                for ((i=0; i<${#connections[@]}; i++)); do
                    IFS='|' read -r name _ <<< "${connections[$i]}"
                    if [[ "$name" == "$choice" ]]; then
                        connect_to_server "${connections[$i]}"
                        found=1
                        break
                    fi
                done
                if [[ $found -eq 0 ]]; then
                    zenity --error --text="Invalid selection: $choice"
                    log_message "Error: Invalid main menu selection '$choice'"
                fi
                ;;
        esac
    done
}

# --- Main Execution ---
check_deps
main_menu
exit 0
