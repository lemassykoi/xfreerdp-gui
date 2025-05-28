#!/usr/bin/env bash

# xfreerdp-gui-yad.sh - A YAD GUI for FreeRDP v3.x (Multi-Stage Menu)
# Adapted from the original by wyllianbs for FreeRDP legacy versions.

# Configuration
CONF_DIR="$HOME/.config/xfreerdp3-gui" 
CONF_FILE="$CONF_DIR/xfreerdp3-gui.conf"
LOG_FILE="$CONF_DIR/xfreerdp3-gui.log"
XFREERDP_CMD="xfreerdp3"

mkdir -p "$CONF_DIR"
touch "$LOG_FILE"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_deps() {
    for cmd_to_check in "$XFREERDP_CMD" yad; do
        if ! command -v "$cmd_to_check" &>/dev/null; then
            # Added --center to this YAD call
            yad --error \
                --text="Error: '$cmd_to_check' command not found. Please install it." \
                --width=300 \
                --button="OK:1" \
                --center
            log_message "Error: Dependency '$cmd_to_check' not found."
            exit 1
        fi
    done
    local actual_version_output=$("$XFREERDP_CMD" --version 2>&1 | head -n 1)
    log_message "Detected $XFREERDP_CMD version: $actual_version_output"
    if ! "$XFREERDP_CMD" --version 2>/dev/null | grep -qE "version (3\.|[4-9]\.)"; then
         yad --warning \
            --text="Warning: Script for FreeRDP v3+. Your version: $actual_version_output" \
            --width=550 \
            --button="OK:0" \
            --center
         log_message "Warning: Version check failed or not v3+."
    fi
    return 0
}

declare -a connections
load_connections() {
    connections=()
    if [[ -f "$CONF_FILE" ]]; then
        local line_num=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            if [[ -z "$line" ]]; then
                continue
            fi
            IFS='|' read -r name _ <<< "$line"
            if [[ -z "$name" ]]; then
                log_message "load_connections: Line $line_num has no name, skipping: [$line]"
                continue
            fi
            connections+=("$line")
        done < "$CONF_FILE"
    fi
    log_message "Connections loaded. Count: ${#connections[@]}"
}

save_connections() {
    if [[ -f "$CONF_FILE" ]]; then
        cp "$CONF_FILE" "$CONF_FILE.bak"
    fi
    if ! printf "%s\n" "${connections[@]}" > "$CONF_FILE"; then
        log_message "ERROR: Failed to save connections to '$CONF_FILE'."
        yad --error --text="ERROR: Could not write to config file."
    else
        log_message "Connections saved."
    fi
}

to_yad_bool() {
    [[ "$1" == "Yes" ]] && echo "TRUE" || echo "FALSE"
}
from_yad_bool() {
    [[ "$1" == "TRUE" ]] && echo "Yes" || echo "No"
}

add_connection() {
    local def_res="1920x1080"
    local def_fs_bool="FALSE"
    local def_snd_bool="TRUE"
    local res_list="1920x1080!Default!1024x768!1280x720!1280x800!1280x1024!1366x768!1440x900!1600x900!1680x1050!1920x1200!Custom"
    local data_pipe
    data_pipe=$(yad --form \
        --title="Add New RDP Connection" \
        --width=500 \
        --height=450 \
        --center \
        --field="Name:" "" \
        --field="Host/IP:" "" \
        --field="User:" "" \
        --field="Pass (ASK if blank):H" "" \
        --field="Domain:" "" \
        --field="Resolution:CBE" "$def_res!$res_list" \
        --field="Fullscreen:CHK" "$def_fs_bool" \
        --field="Sound:CHK" "$def_snd_bool" \
        --field="Share Name:" "" \
        --field="Share Path:DIR" "" \
        --button="gtk-ok:0" \
        --button="gtk-cancel:1" \
        --separator='|')

    if [[ $? -ne 0 ]]; then
        log_message "Add conn cancelled."
        return 1
    fi

    IFS='|' read -r n h u p d r fs_s snd_s dn dp <<< "$data_pipe"
    local fs=$(from_yad_bool "$fs_s")
    local snd=$(from_yad_bool "$snd_s")

    if [[ "$r" == "Custom" ]]; then
        local cr
        cr=$(yad --entry \
            --center \
            --title="Custom Res" \
            --text="Enter WxH:" \
            --button="gtk-ok:0" \
            --button="gtk-cancel:1")
        if [[ $? -eq 0 ]] && [[ "$cr" =~ ^[0-9]+x[0-9]+$ ]]; then
            r="$cr"
        else
            r="$def_res"
        fi
    fi

    if [[ -z "$n" ]] || [[ -z "$h" ]]; then
        yad --error --center --text="Name & Host required." --button="OK:1"
        return 1
    fi

    for ec in "${connections[@]}"; do
        IFS='|' read -r en _ <<< "$ec"
        if [[ "$en" == "$n" ]]; then
            yad --error --center --text="Name '$n' exists." --button="OK:1"
            return 1
        fi
    done

    connections+=("$n|$h|$u|$p|$d|$r|$fs|$snd|$dn|$dp")
    save_connections
    log_message "Added: $n"
    yad --info --center --text="Conn '$n' added." --button="OK:0" --timeout=3
    return 0
}

SELECTED_CONNECTION_DETAILS=""
SELECTED_CONNECTION_INDEX=-1

select_saved_connection() {
    local dialog_title="$1" # Renamed from title to avoid conflict if you have a global 'title'
    local prompt_text="$2"  # Renamed from prompt for same reason
    SELECTED_CONNECTION_DETAILS="" 
    SELECTED_CONNECTION_INDEX=-1   

    if [[ ${#connections[@]} -eq 0 ]]; then
        yad --info \
            --center \
            --text="No saved conns." \
            --button="OK:0"
        return 1
    fi

    local yad_list_input="" # Renamed from y_list_in for clarity
    local i
    for i in "${!connections[@]}"; do
        IFS='|' read -r name _ <<< "${connections[$i]}" # Renamed n to name
        yad_list_input+="$i\n$name\n"
    done

    local choice_idx_val # Renamed from c_idx_val
    choice_idx_val=$(echo -e "$yad_list_input" | yad --list \
        --title="$dialog_title" \
        --text="$prompt_text" \
        --center \
        --column="Index:HD" \
        --column="Name" \
        --width=400 \
        --height=300 \
        --print-column=1 \
        --button="gtk-ok:0" \
        --button="gtk-cancel:1" 2>/dev/null)
    
    local yad_status=$? # Capture YAD's exit status

    # ---- START OF MODIFICATION ----
    # Clean the choice_idx_val to remove potential trailing newline and pipe
    if [[ -n "$choice_idx_val" ]]; then
        choice_idx_val=${choice_idx_val%$'\n'} # Remove trailing newline
        choice_idx_val=${choice_idx_val%|}    # Remove trailing pipe
    fi
    # ---- END OF MODIFICATION ----

    # Handle user cancellation (e.g., Cancel button, ESC, or window closed)
    if [[ $yad_status -ne 0 ]]; then
        log_message "$dialog_title: Selection dialog cancelled by user. YAD status: $yad_status"
        return 1
    fi

    # If YAD status was 0 (OK pressed), then validate the choice
    if ! [[ "$choice_idx_val" =~ ^[0-9]+$ ]]; then
        log_message "$dialog_title: Invalid selection (not a number) after OK. Cleaned value: '$choice_idx_val'. YAD status: $yad_status"
        return 1
    fi
    
    # Check if the numeric index is within the bounds of the connections array
    if (( choice_idx_val < 0 || choice_idx_val >= ${#connections[@]} )); then
        yad --error \
            --center \
            --text="Invalid sel (bounds)." \
            --button="OK:1"
        log_message "Error: Invalid index value '$choice_idx_val' (out of bounds)."
        return 1
    fi
    
    SELECTED_CONNECTION_INDEX="$choice_idx_val"
    SELECTED_CONNECTION_DETAILS="${connections[$SELECTED_CONNECTION_INDEX]}"
    
    # For logging the selected name
    IFS='|' read -r local selected_name _ <<< "$SELECTED_CONNECTION_DETAILS" # Renamed sn to selected_name
    log_message "$dialog_title: Sel idx $SELECTED_CONNECTION_INDEX ('$selected_name'). Details: [$SELECTED_CONNECTION_DETAILS]"
    return 0
}

edit_selected_connection() {
    log_message "edit_sel_conn: CALLED. Idx: $SELECTED_CONNECTION_INDEX, Details: [$SELECTED_CONNECTION_DETAILS]"
    if (( SELECTED_CONNECTION_INDEX < 0 )) || [[ -z "$SELECTED_CONNECTION_DETAILS" ]]; then
        yad --error --center --text="Internal: No conn sel for edit." --button="OK:1"
        return 1
    fi
    IFS='|' read -r on oh ou op od or ofs osnd odn odp <<< "$SELECTED_CONNECTION_DETAILS"
    log_message "Editing YAD: Name='[$on]', Host='[$oh]', Res='[$or]'"
    local ofs_b=$(to_yad_bool "$ofs")
    local osnd_b=$(to_yad_bool "$osnd")
    local res_list="1920x1080!Default!1024x768!..." # Ensure full list here
    local data_pipe
    data_pipe=$(yad --form \
        --title="Edit: $on" \
        --width=500 \
        --height=450 \
        --center \
        --field="Name:" "$on" \
        --field="Host/IP:" "$oh" \
        --field="User:" "$ou" \
        --field="Pass:H" "$op" \
        --field="Domain:" "$od" \
        --field="Resolution:CBE" "$or!$res_list" \
        --field="Fullscreen:CHK" "$ofs_b" \
        --field="Sound:CHK" "$osnd_b" \
        --field="Share Name:" "$odn" \
        --field="Share Path:DIR" "$odp" \
        --button="gtk-ok:0" \
        --button="gtk-cancel:1" \
        --separator='|')

    if [[ $? -ne 0 ]]; then
        log_message "Edit cancelled for $on."
        return 1
    fi

    IFS='|' read -r n h u p d r nfs_b nsnd_b dn dp <<< "$data_pipe"
    local fs=$(from_yad_bool "$nfs_b")
    local snd=$(from_yad_bool "$nsnd_b")

    if [[ "$r" == "Custom" ]]; then
        local cr
        cr=$(yad --entry \
            --center \
            --title="Custom Res" \
            --text="Enter WxH:" \
            --entry-text="$or" \
            --button="gtk-ok:0" \
            --button="gtk-cancel:1")
        if [[ $? -eq 0 ]] && [[ "$cr" =~ ^[0-9]+x[0-9]+$ ]]; then
            r="$cr"
        else
            r="$or"
        fi
    fi

    if [[ -z "$n" ]] || [[ -z "$h" ]]; then
        yad --error --center --text="Name & Host required." --button="OK:1"
        return 1
    fi

    if [[ "$n" != "$on" ]]; then
        for i in "${!connections[@]}"; do
            if ((i == SELECTED_CONNECTION_INDEX)); then
                continue
            fi
            IFS='|' read -r en _ <<< "${connections[$i]}"
            if [[ "$en" == "$n" ]]; then
                yad --error --center --text="Name '$n' exists." --button="OK:1"
                return 1
            fi
        done
    fi
    connections[$SELECTED_CONNECTION_INDEX]="$n|$h|$u|$p|$d|$r|$fs|$snd|$dn|$dp"
    save_connections
    log_message "Edited: $n"
    yad --info --center --text="Conn '$n' updated." --button="OK:0" --timeout=3
    return 0
}

delete_selected_connection() {
    if (( SELECTED_CONNECTION_INDEX < 0 )); then
        yad --error --center --text="Internal: No conn sel." --button="OK:1"
        return 1
    fi
    IFS='|' read -r name_to_del _ <<< "$SELECTED_CONNECTION_DETAILS"
    yad --question \
        --title="Confirm Delete" \
        --text="Delete '$name_to_del'?" \
        --width=300 \
        --center \
        --button="gtk-yes:0" \
        --button="gtk-no:1"
    if [[ $? -eq 0 ]]; then
        unset 'connections[SELECTED_CONNECTION_INDEX]'
        connections=("${connections[@]}")
        save_connections
        log_message "Deleted: $name_to_del"
        yad --info --center --text="'$name_to_del' deleted." --button="OK:0" --timeout=3
        return 0
    else
        log_message "Del cancelled for $name_to_del."
        return 1
    fi
}

connect_to_server() {
    local conn_str="$1"
    local disp_name_override="$2"
    local CN CH CU CP CD CR CFS CSND CDN CDP
    IFS='|' read -r CN CH CU CP CD CR CFS CSND CDN CDP <<< "$conn_str"
    local disp_name="${disp_name_override:-$CN}"
    local XFARGS=()
    XFARGS+=("/v:$CH")

    if [[ -n "$CU" ]]; then
        XFARGS+=("/u:$CU")
    fi

    if [[ "$CP" == "ASK" ]] || ([[ -z "$CP" ]] && [[ -n "$CU" ]]); then
        local pp
        pp=$(yad --entry \
            --center \
            --title="Pass for $CU@$CH" \
            --text="Enter pass:" \
            --hide-text \
            --button="gtk-ok:0" \
            --button="gtk-cancel:1")
        if [[ $? -ne 0 ]]; then
            log_message "Pass prompt cancel."
            return 1
        fi
        if [[ -n "$pp" ]]; then
            XFARGS+=("/p:$pp")
        fi
    elif [[ -n "$CP" ]]; then
        XFARGS+=("/p:$CP")
    fi

    if [[ -n "$CD" ]]; then
        XFARGS+=("/d:$CD")
    fi

    if [[ "$CFS" == "Yes" ]]; then
        XFARGS+=("/f")
    elif [[ "$CR" != "Default" ]] && [[ -n "$CR" ]]; then
        XFARGS+=("/size:$CR")
    fi

    if [[ "$CSND" == "Yes" ]]; then
        XFARGS+=("/sound")
    fi

    if [[ -n "$CDN" ]] && [[ -n "$CDP" ]]; then
        if [[ -d "$CDP" ]]; then
            XFARGS+=("/drive:$CDN,$CDP")
        else
            yad --warning --center --text="Drive path '$CDP' DNE." --button="OK:0"
        fi
    fi

    XFARGS+=("/network:auto" "/clipboard" "/fonts" "/dynamic-resolution")
    local xf_log="$LOG_FILE.$XFREERDP_CMD.$(date +%s%N).$$"
    yad --info \
        --text="Connecting to '$disp_name'...\nLog: $xf_log" \
        --timeout=20 \
        --center \
        --button="OK:0" &
    local yad_pid=$!

    (setsid "$XFREERDP_CMD" "${XFARGS[@]}" > "$xf_log" 2>&1 &)
    local xf_pid=$!
    sleep 0.2

    if ! ps -p $xf_pid > /dev/null; then
        log_message "xf $xf_pid for '$disp_name' exited quick. Log: $xf_log"
        kill "$yad_pid" 2>/dev/null
        wait "$yad_pid" 2>/dev/null
        local err_snip
        err_snip=$(grep -m1 -Ei "ERRCONNECT|ERROR" "$xf_log" || echo "Unknown err")
        yad --error \
            --center \
            --text="Failed to connect '$disp_name'.\nLog:\n${err_snip:0:150}...\n\nFull: $xf_log" \
            --button="OK:1"
    else
        log_message "xf $xf_pid for '$disp_name' running."
    fi
}

quick_connect() {
    local def_res="1920x1080"
    local def_fs_bool="FALSE"
    local def_snd_bool="TRUE"
    local res_list="1920x1080!Default!1024x768!..." # Same as add_connection
    local data_pipe
    data_pipe=$(yad --form \
        --title="Quick Connect" \
        --width=500 \
        --height=400 \
        --center \
        --field="Host/IP:" "" \
        --field="User:" "" \
        --field="Pass (ASK if blank):H" "" \
        --field="Domain:" "" \
        --field="Resolution:CBE" "$def_res!$res_list" \
        --field="Fullscreen:CHK" "$def_fs_bool" \
        --field="Sound:CHK" "$def_snd_bool" \
        --button="gtk-ok:0" \
        --button="gtk-cancel:1" \
        --separator='|')

    if [[ $? -ne 0 ]]; then
        log_message "QC cancelled."
        return 1
    fi

    IFS='|' read -r h u p d r fs_b snd_b <<< "$data_pipe"
    local fs=$(from_yad_bool "$fs_b")
    local snd=$(from_yad_bool "$snd_b")

    if [[ "$r" == "Custom" ]]; then
        local cr
        cr=$(yad --entry \
            --center \
            --title="Custom Res" \
            --text="Enter WxH:" \
            --button="gtk-ok:0" \
            --button="gtk-cancel:1")
        if [[ $? -eq 0 ]] && [[ "$cr" =~ ^[0-9]+x[0-9]+$ ]]; then
            r="$cr"
        else
            r="$def_res"
        fi
    fi

    if [[ -z "$h" ]]; then
        yad --error --center --text="Host required." --button="OK:1"
        return 1
    fi
    connect_to_server "|$h|$u|$p|$d|$r|$fs|$snd||" "$h"
    return 0
}

manage_saved_connections_menu() {
    if ! select_saved_connection "Connect to Saved Server" "Select to CONNECT, or Cancel for Main Menu:"; then
        return
    fi
    connect_to_server "$SELECTED_CONNECTION_DETAILS"
}

main_menu() {
    while true; do
        load_connections
        local main_actions_input=""
        local can_manage_saved=false
        if [[ ${#connections[@]} -gt 0 ]]; then
            main_actions_input+="Connect to Saved Server\n"
            can_manage_saved=true
        fi
        main_actions_input+="Quick Connect\nAdd New Connection\n"
        if $can_manage_saved; then # Use the flag
            main_actions_input+="Edit Saved Connection\nDelete Saved Connection\n"
        fi
        main_actions_input+="View Log\nExit"

        local choice
        choice=$(echo -e "$main_actions_input" | yad --list \
            --title="$XFREERDP_CMD-gui (YAD)" \
            --text="Select an action:" \
            --column="Actions" \
            --width=350 \
            --height=350 \
            --center \
            --button="gtk-ok:0" \
            --button="gtk-cancel:1" 2>/dev/null)
        
        local yad_status=$?
        
        # Remove trailing newline AND pipe from YAD's choice if it's not empty
        if [[ -n "$choice" ]]; then
            choice=${choice%$'\n'} # Remove trailing newline
            choice=${choice%|}    # Remove trailing pipe
        fi

        # Exit conditions: Cancel button pressed (status != 0) OR "Exit" chosen AND OK pressed (status == 0)
        if [[ $yad_status -ne 0 ]]; then
            log_message "Main menu cancelled by user (Cancel button or ESC)."
            break # Exit while loop
        fi
        
        if [[ "$choice" == "Exit" ]]; then # This comparison should now work
            log_message "User selected 'Exit' from main menu."
            break # Exit while loop
        fi
        
        if [[ -z "$choice" ]]; then
            log_message "Main menu returned empty choice with OK status. Treating as cancel."
            break
        fi

        log_message "Main menu choice (cleaned): [$choice]" # Log the cleaned choice
        case "$choice" in
            "Connect to Saved Server")
                manage_saved_connections_menu
                ;;
            "Quick Connect")
                quick_connect
                ;;
            "Add New Connection")
                add_connection
                ;;
            "Edit Saved Connection")
                if select_saved_connection "Edit" "Select to EDIT:"; then
                    edit_selected_connection
                fi
                ;;
            "Delete Saved Connection")
                if select_saved_connection "Delete" "Select to DELETE:"; then
                    delete_selected_connection
                fi
                ;;
            "View Log")
                yad --text-info \
                    --center \
                    --filename="$LOG_FILE" \
                    --editable \
                    --width=800 \
                    --height=600 \
                    --button="OK:0" > /dev/null
                ;;
            *)
                log_message "Unknown main menu choice (should not happen): [$choice]"
                ;;
        esac
    done
}

# --- Main Execution ---
log_message "Application starting (YAD version)..."
check_deps
if [[ $? -eq 0 ]]; then
    main_menu
fi
log_message "Application ended (YAD version)."
exit 0
