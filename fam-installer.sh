#!/bin/bash

# ==============================================================================
# FAM - FLATPAK ALIAS MANAGER v1.0
# ==============================================================================
# Copyright (c) 2026 Vuk Hidalgo
# Licensed under the GNU General Public License v3.0 (GPLv3)
# SPDX-License-Identifier: GPL-3.0-only
#
# DESCRIPTION:
#   A robust automation tool that synchronizes Flatpak apps to native shell
#   aliases. Supports BASH, ZSH, and FISH shells natively.
#   Features background monitoring, auto-cleanup, and rich dashboard output.
#
# CREDITS:
#   Original Concept & Logic: Vuk Hidalgo
#   Refactoring & AI Assistance: Google Gemini
# ==============================================================================

# --- MODULE: VISUALS ---
# Sets up ANSI escape codes for colored terminal output.
setup_colors() {
    BOLD="\033[1m"; DIM="\033[2m"; GREEN="\033[32m"; RED="\033[31m"
    YELLOW="\033[33m"; BLUE="\033[34m"; MAGENTA="\033[35m"; RESET="\033[0m"
    SEP="------------------------------------------------------------"
}

# Clears screen and prints the stylized logo/header.
print_header() {
    clear
    setup_colors
    echo -e "${BLUE}${BOLD}${SEP}${RESET}"
    echo -e "${MAGENTA}${BOLD}   FAM - FLATPAK ALIAS MANAGER v1.0 ${RESET}"
    echo -e "${BLUE}${BOLD}${SEP}${RESET}"
    echo -e "${DIM}   A robust automation tool that synchronizes Flatpak"
    echo -e "   apps to native shell aliases."
    echo -e ""
    echo -e "   • Supports BASH, ZSH, and FISH shells natively."
    echo -e "   • Features background monitoring, auto-cleanup,"
    echo -e "     and rich dashboard output.${RESET}\n"
}

# A helper to print aligned status messages (e.g., Action ...... [OK]).
log_action() {
    local action="$1"; local detail="$2"; local status="$3"
    # Calculate padding to align the status tag
    local pad_len=$(( 30 - ${#action} )); if [ $pad_len -lt 1 ]; then pad_len=1; fi
    local dots=$(printf "%0.s." $(seq 1 $pad_len))
    
    if [ "$status" -eq 0 ]; then
        echo -e " ${BOLD}${action}${RESET} ${DIM}${dots}${RESET} ${GREEN}[OK]${RESET} ${DIM}${detail}${RESET}"
    else
        echo -e " ${BOLD}${action}${RESET} ${DIM}${dots}${RESET} ${RED}[FAIL]${RESET} ${DIM}${detail}${RESET}"
    fi
}

# --- MODULE: CONFIGURATION ---
# Define install paths and systemd locations.
SCRIPT_NAME="fam"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_DIR/fam.service"
PATH_FILE="$SYSTEMD_DIR/fam.path"

# User configuration paths
ALIAS_DIR="$HOME/.bashrc.d"
ALIAS_FILE_SH="$ALIAS_DIR/flatpak-aliases.sh"    # POSIX (Bash/Zsh)
ALIAS_FILE_FISH="$ALIAS_DIR/flatpak-aliases.fish" # Fish Shell
SENTINEL_FILE="$ALIAS_DIR/.fam_sentinel"          # Used for race condition handling
INSTALL_DIR="$HOME/.local/bin"

# Markers used to identify FAM's code block inside .bashrc/.zshrc for easy removal
MARKER_START="# --- FAM CONFIG (DO NOT EDIT) ---"
MARKER_END="# --- END FAM CONFIG ---"

# --- MODULE: PAYLOAD GENERATION ---
# This function generates the actual 'fam' binary script that runs on the system.
generate_worker_script() {
    # We use a quoted heredoc ('EOF_WORKER') so that variables ($HOME, etc.) 
    # are NOT expanded now. They will be expanded when the user runs the generated script.
    cat << 'EOF_WORKER'
#!/bin/bash
ALIAS_DIR="$HOME/.bashrc.d"
ALIAS_FILE_SH="$ALIAS_DIR/flatpak-aliases.sh"
ALIAS_FILE_FISH="$ALIAS_DIR/flatpak-aliases.fish"
SENTINEL_FILE="$ALIAS_DIR/.fam_sentinel"
BOLD="\033[1m"; DIM="\033[2m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; RESET="\033[0m"
SEP="------------------------------------------------------------"

# Ensure alias directory exists
mkdir -p "$ALIAS_DIR"
TMP_SH=$(mktemp)
TMP_FISH=$(mktemp)

# 1. CLEANUP: Remove unused runtimes (libraries) to save disk space
if command -v flatpak >/dev/null; then
    flatpak uninstall --unused --noninteractive &>/dev/null
fi

# 2. GENERATION: Create alias files
echo "# FAM AUTO-GENERATED (Bash/Zsh)" > "$TMP_SH"
echo "# FAM AUTO-GENERATED (Fish)" > "$TMP_FISH"

# Get raw list of installed apps (ID and Name)
flatpak list --app --columns=application,name | sort > "$TMP_SH.list"
count=0

while IFS=$'\t' read -r app_id app_name; do
    # Sanitize App Name: Lowercase -> Replace spaces with hyphens -> Remove special chars
    # Example: "Visual Studio Code" -> "visual-studio-code"
    clean_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    [ -z "$clean_name" ] && continue
    
    # Conflict Check: If a native command exists (e.g. 'python'), append '-flatpak'
    final_alias="$clean_name"
    if type -P "$clean_name" &>/dev/null; then final_alias="${clean_name}-flatpak"; fi
    
    # Write syntax for Bash/Zsh
    echo "alias $final_alias='flatpak run $app_id'" >> "$TMP_SH"
    # Write syntax for Fish
    echo "alias $final_alias \"flatpak run $app_id\"" >> "$TMP_FISH"
    ((count++))
done < "$TMP_SH.list"
rm -f "$TMP_SH.list"

# 3. LOGIC & RACE CONDITION HANDLING
# If Systemd runs this script in background, it might update the file before the terminal 
# wrapper runs. We use a "Sentinel" file to communicate that an update just happened.
CHANGES=0
if cmp -s "$TMP_SH" "$ALIAS_FILE_SH"; then
    # Files are identical. Did we just update it recently?
    if [ -f "$SENTINEL_FILE" ]; then
        now=$(date +%s); file_time=$(date -r "$SENTINEL_FILE" +%s)
        # If update happened in last 60s, consider it a "Change" for user feedback
        if [ $((now - file_time)) -lt 60 ]; then CHANGES=1; rm -f "$SENTINEL_FILE"; fi
    fi
else
    # Files differ, real update needed
    CHANGES=1; touch "$SENTINEL_FILE"
fi

# 4. APPLY CHANGES (Move temp files to real files)
if [ $CHANGES -eq 1 ]; then
    if ! [ -f "$ALIAS_FILE_SH" ] || ! cmp -s "$TMP_SH" "$ALIAS_FILE_SH"; then
        mv "$TMP_SH" "$ALIAS_FILE_SH"; chmod +x "$ALIAS_FILE_SH"
    fi
    if ! [ -f "$ALIAS_FILE_FISH" ] || ! cmp -s "$TMP_FISH" "$ALIAS_FILE_FISH"; then
        mv "$TMP_FISH" "$ALIAS_FILE_FISH"
    fi
fi
rm -f "$TMP_SH" "$TMP_FISH"

# 5. OUTPUT HANDLING
# If running in a Terminal (-t 1), show the Dashboard.
# If running in Background (Systemd), show a Notification bubble.
if [ -t 1 ]; then
    echo ""
    echo -e "${BLUE}${BOLD}${SEP}${RESET}"
    echo -e "${BOLD} FAM - STATUS REPORT ${RESET}"
    echo -e "${BLUE}${BOLD}${SEP}${RESET}"
    if [ $CHANGES -eq 1 ]; then
        echo -e " ${GREEN}[+]${RESET} Aliases synchronized"
        echo -e " ${GREEN}[+]${RESET} Unused runtimes cleaned"
    else
        echo -e " ${YELLOW}[=]${RESET} No changes necessary"
    fi
    echo -e " ${BLUE}[i]${RESET} Total Aliases:  ${BOLD}${count}${RESET}"
    echo -e "${BLUE}${BOLD}${SEP}${RESET}\n"
else
    if [ $CHANGES -eq 1 ] && command -v notify-send >/dev/null; then
         # Prevent double notification if invoked by shell wrapper (Check Parent PID)
         if [ "$PPID" -ne "$$" ]; then notify-send -u low -a "FAM" "Aliases Updated" "Synced $count apps."; fi
    fi
fi
EOF_WORKER
}

# --- MODULE: SHELL INTEGRATION (BASH & ZSH) ---
# Creates the function that intercepts 'flatpak' commands in Bash/Zsh
generate_posix_wrapper() {
    local script_path="$1"
    echo "$MARKER_START"
    # Unquoted heredoc (EOF_WRAPPER) allows us to inject $script_path dynamically
    cat <<EOF_WRAPPER
flatpak() {
    command flatpak "\$@"
    local status=\$?
    if [ \$status -eq 0 ]; then
        # Only trigger update on modification commands
        case "\$1" in
            install|uninstall|remove|update)
                if [ -x "$script_path" ]; then
                    "$script_path"
                fi
                ;;
        esac
    fi
    return \$status
}
EOF_WRAPPER
    echo "$MARKER_END"
}

# Injects the configuration into .bashrc or .zshrc
update_posix_config() {
    local rc_file="$1"
    local script_path="$2"
    [ ! -f "$rc_file" ] && return
    
    # 1. Clean old FAM entries (idempotency check)
    if grep -qF "$MARKER_START" "$rc_file"; then
        sed -i "/$MARKER_START/,/$MARKER_END/d" "$rc_file"
    fi

    # 2. Append new config
    cat <<END_CONFIG >> "$rc_file"

# Added by FAM (Flatpak Alias Manager)
if [ -z "\${PATH##*$HOME/.local/bin*}" ] && [ -d "$HOME/.local/bin" ]; then
    export PATH="\$HOME/.local/bin:\$PATH"
fi
if [ -f "$HOME/.bashrc.d/flatpak-aliases.sh" ]; then
    source "$HOME/.bashrc.d/flatpak-aliases.sh"
fi
END_CONFIG
    
    # 3. Append the wrapper function
    generate_posix_wrapper "$script_path" >> "$rc_file"
    
    log_action "Configuring Shell" "$(basename "$rc_file")" 0
}

# --- MODULE: SHELL INTEGRATION (FISH) ---
# Creates the configuration for Fish shell users
update_fish_config() {
    local script_path="$1"
    if ! command -v fish >/dev/null; then return; fi

    local fish_conf_dir="$HOME/.config/fish/conf.d"
    local fish_fam_file="$fish_conf_dir/fam.fish"
    mkdir -p "$fish_conf_dir"

    # Create the Fish wrapper using 'function --wraps'
    cat > "$fish_fam_file" <<EOF_FISH
# FAM - Flatpak Alias Manager for Fish
if test -f "$HOME/.bashrc.d/flatpak-aliases.fish"
    source "$HOME/.bashrc.d/flatpak-aliases.fish"
end

function flatpak --wraps flatpak
    command flatpak \$argv
    set -l func_status \$status
    if test \$func_status -eq 0
        # Check command type using regex
        if string match -r "^(install|uninstall|remove|update)$" -- \$argv[1] > /dev/null 2>&1
            if test -x "$script_path"
                "$script_path"
            end
        end
    end
    return \$func_status
end
EOF_FISH
    log_action "Configuring Fish" "Created conf.d/fam.fish" 0
}

# --- MODULE: INSTALLATION ---
# Main function to install binary, systemd services, and shell hooks
install_components() {
    local target="$INSTALL_DIR/$SCRIPT_NAME"
    echo -e "${BLUE}${BOLD}${SEP}${RESET}\n${BOLD} INSTALLATION PROGRESS ${RESET}\n${BLUE}${BOLD}${SEP}${RESET}"

    # 1. Install Binary
    local tmp_script=$(mktemp)
    generate_worker_script > "$tmp_script"
    mkdir -p "$INSTALL_DIR"
    if mv "$tmp_script" "$target" && chmod +x "$target"; then
        log_action "Binary Installation" "$target" 0
    else
        log_action "Binary Installation" "Failed to move/chmod" 1; return
    fi

    # 2. Configure Systemd (Background Watcher)
    mkdir -p "$SYSTEMD_DIR"
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=FAM - Flatpak Alias Manager
[Service]
Type=oneshot
ExecStart=$target
EOF
    cat > "$PATH_FILE" <<EOF
[Unit]
Description=Watch for Flatpak Installs
[Path]
PathChanged=%h/.local/share/flatpak/exports/share/applications
PathChanged=/var/lib/flatpak/exports/share/applications
Unit=fam.service
[Install]
WantedBy=default.target
EOF
    log_action "Systemd Configuration" "Service & Path Units" 0

    # 3. Configure Shells
    if [ -f "$HOME/.bashrc" ]; then update_posix_config "$HOME/.bashrc" "$target"; fi
    if [ -f "$HOME/.zshrc" ];  then update_posix_config "$HOME/.zshrc" "$target"; fi
    update_fish_config "$target"

    # 4. Activate Services
    systemctl --user daemon-reload
    systemctl --user enable --now fam.path >/dev/null
    log_action "Service Activation" "Background Watcher Started" 0
    
    # 5. Initial Run
    "$target" >/dev/null
    log_action "Initial Sync" "Aliases Generated" 0

    echo -e "${BLUE}${BOLD}${SEP}${RESET}\n ${GREEN}[✔] SYSTEM READY${RESET}\n ${DIM}    Restart your terminal to start using aliases.${RESET}\n${BLUE}${BOLD}${SEP}${RESET}\n"
}

# --- MODULE: UNINSTALLATION ---
# Removes all traces of FAM from the system
remove_components() {
    echo -e "${BLUE}${BOLD}${SEP}${RESET}\n${BOLD} UNINSTALLATION PROGRESS ${RESET}\n${BLUE}${BOLD}${SEP}${RESET}"
    
    # 1. Stop Services
    systemctl --user stop fam.path 2>/dev/null
    systemctl --user disable fam.path 2>/dev/null
    rm -f "$SERVICE_FILE" "$PATH_FILE"
    log_action "Stopping Services" "Background Watcher" 0
    
    # 2. Remove Binary
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
    log_action "Removing Binary" "$INSTALL_DIR/$SCRIPT_NAME" 0
    
    # 3. Clean Data & Aliases
    rm -f "$ALIAS_FILE_SH" "$ALIAS_FILE_FISH" "$SENTINEL_FILE"
    log_action "Cleaning Data" "~/.bashrc.d/" 0
    
    # 4. Restore Shell Configs (Remove block between markers)
    if [ -f "$HOME/.bashrc" ]; then sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOME/.bashrc"; fi
    if [ -f "$HOME/.zshrc" ]; then sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOME/.zshrc"; fi
    log_action "Restoring Shells" ".bashrc / .zshrc" 0

    # 5. Restore Fish
    rm -f "$HOME/.config/fish/conf.d/fam.fish"
    log_action "Restoring Fish" "Removed conf.d/fam.fish" 0

    systemctl --user daemon-reload
    echo -e "${BLUE}${BOLD}${SEP}${RESET}\n ${GREEN}[✔] UNINSTALLED${RESET}\n ${DIM}    System returned to original state.${RESET}\n${BLUE}${BOLD}${SEP}${RESET}\n"
}

# --- MAIN MENU ---
print_header
INSTALLED=0
# Check if FAM is currently installed by looking for the systemd unit
if systemctl --user list-unit-files | grep -q "fam.path"; then INSTALLED=1; fi

if [ $INSTALLED -eq 1 ]; then
    echo -e "   Current Status: ${GREEN}${BOLD}INSTALLED${RESET}"
    echo -e "\n   [1] Remove FAM (Delete everything)"
    echo -e "   [2] Reinstall / Update"
    echo -e "   [3] Exit"
    read -p "$(echo -e "\n   ${BOLD}Select:${RESET} ")" opt
    case $opt in
        1) remove_components ;;
        2) remove_components; install_components ;;
        *) exit ;;
    esac
else
    echo -e "   Current Status: ${RED}${BOLD}NOT INSTALLED${RESET}"
    echo -e "\n   [1] Install FAM"
    echo -e "   [2] Exit"
    read -p "$(echo -e "\n   ${BOLD}Select:${RESET} ")" opt
    case $opt in
        1) install_components ;;
        *) exit ;;
    esac
fi
