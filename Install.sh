#!/bin/bash
#
# ██╗███╗   ██╗████████╗ ██████╗ ██████╗ ██████╗  ██████╗
# ██║████╗  ██║╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝
# ██║██╔██╗ ██║   ██║   ██║   ██║██████╔╝██████╔╝██║     
# ██║██║╚██╗██║   ██║   ██║   ██║██╔══██╗██╔═══╝ ██║     
# ██║██║ ╚████║   ██║   ╚██████╔╝██║  ██║██║     ╚██████╗
# ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝      ╚═════╝
#
# Installer for Rajchauhan28's Hyprland Dotfiles

set -Eeuo pipefail

readonly REPO_URL="https://github.com/rajchauhan28/hypr-dotfiles.git"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Components superseded by the Quickshell suite.  Keep this list explicit so
# detection is predictable and never mistakes an unrelated process for a
# locker merely because its name contains "lock".
readonly -a LEGACY_LOCKERS=(
    hyprlock
    swaylock
    swaylock-effects
    gtklock
    waylock
    i3lock
    i3lock-color
    xsecurelock
    betterlockscreen
    physlock
)

declare -a LEGACY_COMPONENTS_FOUND=()
declare -a LEGACY_SERVICE_UNITS=()
declare -a LEGACY_AUTOSTART_FILES=()
BACKUP_DIR=""

# --- BOOTSTRAP LOGIC ---
# A process-substitution launch (bash <(curl ...)) has no repository beside the
# script, so clone/update it first. A checked-out script always uses its own
# directory and therefore works from any caller's current working directory.
if [ ! -f "$SCRIPT_DIR/package_list.txt" ]; then
    echo -e "\033[0;34mRunning in bootstrap mode...\033[0m"
    
    # Check for git
    if ! command -v git &>/dev/null; then
        echo -e "\033[0;31mError: git is not installed. Please install git first.\033[0m"
        exit 1
    fi

    INSTALL_DIR="$HOME/hypr-dotfiles"

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "\033[0;33mDirectory $INSTALL_DIR already exists. Updating...\033[0m"
        cd "$INSTALL_DIR"
        git pull
    else
        echo -e "\033[0;34mCloning repository to $INSTALL_DIR...\033[0m"
        git clone --depth=1 "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi

    echo -e "\033[0;32mRepository ready. Launching installer...\033[0m"
    chmod +x Install.sh
    exec ./Install.sh "$@"
fi

# Run every relative-path operation from the repository root, regardless of
# the directory from which the user invoked this script.
readonly REPO_DIR="$SCRIPT_DIR"
cd "$REPO_DIR"

# --- GLOBAL VARIABLES ---
# Define colors for output messages
readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

# Configuration directories to be installed
readonly ALL_CONFIG_DIRS=(
    ghostty
    hypr
    mpv
    nvim
    pypr
    quickshell
    wlogout
    walker
    yazi
    ReignShell
    walllust
    rofi
    systemd
)

# Directories containing scripts that need executable permissions
readonly SCRIPT_DIRS=(
    "hypr"
    "quickshell/topbar"
    "quickshell/leftbar"
    "quickshell/sidepanel"
    "quickshell/dock"
    "quickshell/overview"
    "quickshell/settings"
    "quickshell/lock"
)

# --- UTILITY FUNCTIONS ---

# msg <color> <message>
# Prints a message with a specified color.
msg() {
    echo -e "${1}${2}${C_RESET}"
}

# append_unique <array-name> <value>
append_unique() {
    local -n target_array="$1"
    local value="$2"
    local existing

    for existing in "${target_array[@]}"; do
        [ "$existing" = "$value" ] && return
    done
    target_array+=("$value")
}

# --- CORE FUNCTIONS ---

# Find panel/locker components which can continue running independently of the
# Hyprland config.  The old Hyprland files are backed up by stow_configs(), but
# user services and XDG autostart entries also need to be disabled explicitly.
detect_legacy_shell_components() {
    msg "$C_CYAN" "🔎 Checking for Waybar and existing lockscreen components..."

    local component
    for component in waybar swayidle "${LEGACY_LOCKERS[@]}"; do
        if command -v "$component" &>/dev/null \
                || pgrep -x "$component" &>/dev/null \
                || [ -e "$HOME/.config/$component" ] \
                || [ -L "$HOME/.config/$component" ]; then
            append_unique LEGACY_COMPONENTS_FOUND "$component"
        fi
    done

    # Even an unknown/custom locker is covered when it is wired through the
    # Hyprland or hypridle configuration: stow_configs() replaces that config
    # with this repository's `qs -c lock` command.
    local lock_config
    for lock_config in "$HOME/.config/hypr/hypridle.conf" \
                       "$HOME/.config/hypr/hyprland.conf" \
                       "$HOME/.config/hypridle.conf"; do
        if [ -f "$lock_config" ] \
                && grep -Eqi '(^[[:space:]]*lock_cmd[[:space:]]*=|bind.*exec,.*lock)' "$lock_config" \
                && ! grep -Eqi '(^[[:space:]]*lock_cmd[[:space:]]*=|bind.*exec,).*qs[[:space:]]+-c[[:space:]]+lock' "$lock_config"; then
            append_unique LEGACY_COMPONENTS_FOUND "custom-lock-command"
        fi
    done

    # Discover both standard unit names and custom unit files whose Exec line
    # launches a known bar, idle daemon, or locker.
    if command -v systemctl &>/dev/null; then
        local unit _state
        while read -r unit _state; do
            case "$unit" in
                waybar*.service|swayidle*.service|hyprlock*.service|\
                swaylock*.service|gtklock*.service|waylock*.service|\
                i3lock*.service|xsecurelock*.service|betterlockscreen*.service|\
                physlock*.service)
                    append_unique LEGACY_SERVICE_UNITS "$unit"
                    ;;
            esac
        done < <(systemctl --user list-unit-files --type=service --no-legend 2>/dev/null || true)
    fi

    local user_unit_dir="$HOME/.config/systemd/user"
    if [ -d "$user_unit_dir" ]; then
        local unit_file
        while IFS= read -r -d '' unit_file; do
            if grep -Eqi '^[[:space:]]*Exec(Start|StartPre)=.*(waybar|swayidle|hyprlock|swaylock|gtklock|waylock|i3lock|xsecurelock|betterlockscreen|physlock)' "$unit_file"; then
                append_unique LEGACY_SERVICE_UNITS "$(basename "$unit_file")"
            fi
        done < <(find "$user_unit_dir" -maxdepth 1 -type f -name '*.service' -print0 2>/dev/null)
    fi

    local autostart_dir="$HOME/.config/autostart"
    if [ -d "$autostart_dir" ]; then
        local desktop_file
        while IFS= read -r -d '' desktop_file; do
            if grep -Eqi '^[[:space:]]*Exec=.*(waybar|swayidle|hyprlock|swaylock|gtklock|waylock|i3lock|xsecurelock|betterlockscreen|physlock)' "$desktop_file"; then
                append_unique LEGACY_AUTOSTART_FILES "$desktop_file"
            fi
        done < <(find "$autostart_dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    fi

    if [ ${#LEGACY_COMPONENTS_FOUND[@]} -eq 0 ] \
            && [ ${#LEGACY_SERVICE_UNITS[@]} -eq 0 ] \
            && [ ${#LEGACY_AUTOSTART_FILES[@]} -eq 0 ]; then
        msg "$C_GREEN" "✅ No conflicting panel or lockscreen setup detected."
        return
    fi

    if [ ${#LEGACY_COMPONENTS_FOUND[@]} -gt 0 ]; then
        msg "$C_YELLOW" "  -> Detected components: ${LEGACY_COMPONENTS_FOUND[*]}"
    fi
    if [ ${#LEGACY_SERVICE_UNITS[@]} -gt 0 ]; then
        msg "$C_YELLOW" "  -> Detected user services: ${LEGACY_SERVICE_UNITS[*]}"
    fi
    if [ ${#LEGACY_AUTOSTART_FILES[@]} -gt 0 ]; then
        msg "$C_YELLOW" "  -> Detected conflicting XDG autostart entries."
    fi
    msg "$C_BLUE" "  -> They will be backed up and replaced by the Quickshell suite."
}

# Function to check for an AUR helper (yay or paru) and install yay if neither is found.
check_aur_helper() {
    msg "$C_CYAN" "🔎 Checking for AUR helper (yay/paru)..."
    if command -v yay &>/dev/null; then
        msg "$C_GREEN" "✅ yay is already installed."
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        msg "$C_GREEN" "✅ paru is already installed."
        AUR_HELPER="paru"
    else
        msg "$C_YELLOW" "⚠️ No AUR helper found. Installing yay..."
        if ! sudo pacman -S --noconfirm --needed git base-devel; then
            msg "$C_RED" "❌ Failed to install dependencies for yay. Aborting."
            exit 1
        fi
        
        local temp_dir
        temp_dir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay.git "$temp_dir"
        (cd "$temp_dir" && makepkg -si --noconfirm)
        
        if command -v yay &>/dev/null; then
            msg "$C_GREEN" "✅ yay installed successfully."
            AUR_HELPER="yay"
        else
            msg "$C_RED" "❌ Failed to install yay. Please install it manually and re-run the script."
            exit 1
        fi
    fi
}

# Function to install packages from package_list.txt
install_packages() {
    msg "$C_CYAN" "📦 Reading package list and installing packages..."
    local package_file="package_list.txt"
    if [ ! -f "$package_file" ]; then
        msg "$C_YELLOW" "⚠️ $package_file not found. Skipping package installation."
        return
    fi
    
    # Convert file content to an array, ignoring empty lines and comments
    mapfile -t PACKAGES < <(grep -vE '^\s*#|^\s*$' "$package_file")
    
    if [ ${#PACKAGES[@]} -eq 0 ]; then
        msg "$C_YELLOW" "⚠️ No packages found in $package_file. Skipping."
        return
    fi
    
    msg "$C_BLUE" "Installing ${#PACKAGES[@]} packages. This may take a while..."
    if ! "$AUR_HELPER" -Syu --noconfirm --needed "${PACKAGES[@]}"; then
        msg "$C_YELLOW" "⚠️ Bulk package installation failed, possibly due to conflicts."
        msg "$C_CYAN" "🔄 Attempting fallback method: installing packages individually to exclude conflicting ones..."
        for pkg in "${PACKAGES[@]}"; do
            msg "$C_BLUE" "  -> Installing $pkg..."
            if ! "$AUR_HELPER" -S --noconfirm --needed "$pkg"; then
                msg "$C_RED" "    ❌ Failed to install $pkg. It might be conflicting or unavailable. Skipping."
            else
                msg "$C_GREEN" "    ✅ Installed $pkg."
            fi
        done
    else
        msg "$C_GREEN" "✅ All packages installed successfully."
    fi
}

# Function to setup Hyprland plugins using hyprpm
setup_hyprpm() {
    msg "$C_CYAN" "🔌 Setting up Hyprland plugins..."
    if ! command -v hyprpm &>/dev/null; then
        msg "$C_YELLOW" "⚠️ hyprpm not found. Is Hyprland installed? Skipping plugin setup."
        return
    fi

    # Update hyprpm headers
    msg "$C_BLUE" "  -> Updating hyprpm headers..."
    if ! hyprpm update; then
        msg "$C_RED" "❌ Failed to update hyprpm headers."
    fi



    # Add and enable Hyprspace
    msg "$C_BLUE" "  -> Adding Hyprspace..."
    if hyprpm add https://github.com/KZDKM/Hyprspace; then
        hyprpm enable Hyprspace
        msg "$C_GREEN" "    -> Hyprspace enabled."
    else
        msg "$C_YELLOW" "    -> Failed to add Hyprspace or already added."
    fi

    msg "$C_GREEN" "✅ Hyprland plugins setup complete."
}

# Function to backup existing configs and use stow to link the new ones.
stow_configs() {
    BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    msg "$C_CYAN" "📂 Backing up existing configs to $BACKUP_DIR and applying Stow..."
    
    mkdir -p "$BACKUP_DIR/.config"
    
    # Backup existing configs that are about to be stowed
    for dir in "${ALL_CONFIG_DIRS[@]}"; do
        local dest="$HOME/.config/$dir"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            msg "$C_YELLOW" "  -> Backing up '$dir'..."
            mv "$dest" "$BACKUP_DIR/.config/"
        fi
    done

    # These configurations are not supplied by this repository, but leaving
    # them in place makes it easy for a user service or autostart file to bring
    # the old UI back. Preserve them beside the normal dotfile backup.
    local legacy_config
    for legacy_config in waybar swayidle "${LEGACY_LOCKERS[@]}"; do
        local legacy_path="$HOME/.config/$legacy_config"
        if [ -e "$legacy_path" ] || [ -L "$legacy_path" ]; then
            msg "$C_YELLOW" "  -> Backing up legacy '$legacy_config' config..."
            mkdir -p "$BACKUP_DIR/.config"
            mv "$legacy_path" "$BACKUP_DIR/.config/"
        fi
    done

    local autostart_file
    for autostart_file in "${LEGACY_AUTOSTART_FILES[@]}"; do
        if [ -e "$autostart_file" ] || [ -L "$autostart_file" ]; then
            msg "$C_YELLOW" "  -> Disabling autostart '$(basename "$autostart_file")'..."
            mkdir -p "$BACKUP_DIR/.config/autostart-disabled"
            mv "$autostart_file" "$BACKUP_DIR/.config/autostart-disabled/"
        fi
    done
    
    # Backup potential conflicting loose files before stow
    local loose_files=(
        ".local/bin/auralink"
        ".local/bin/auralink-bt"
        ".local/share/applications/auralink.desktop"
        ".local/share/applications/auralink-bt.desktop"
    )
    for lfile in "${loose_files[@]}"; do
        local dest="$HOME/$lfile"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            msg "$C_YELLOW" "  -> Backing up '$lfile'..."
            mkdir -p "$BACKUP_DIR/$(dirname "$lfile")"
            mv "$dest" "$BACKUP_DIR/$lfile"
        fi
    done
    
    if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$BACKUP_DIR/"
    fi
    
    msg "$C_BLUE" "  -> Applying GNU Stow from stow_base..."
    cd stow_base
    stow -t "$HOME" .
    cd ..
    
    msg "$C_GREEN" "✅ Config files successfully stowed."
}

# Disable independently launched legacy components and activate the replacements
# after the new files and executable permissions are in place.
activate_quickshell_replacements() {
    msg "$C_CYAN" "🔄 Activating Quickshell panel and lockscreen replacements..."

    if command -v systemctl &>/dev/null; then
        local unit
        for unit in "${LEGACY_SERVICE_UNITS[@]}"; do
            if ! systemctl --user disable --now "$unit" &>/dev/null; then
                msg "$C_YELLOW" "  -> Could not disable '$unit'; it may already be inactive."
            else
                msg "$C_GREEN" "  -> Disabled legacy service '$unit'."
            fi
        done

        systemctl --user daemon-reload 2>/dev/null || true
        if systemctl --user enable --now hypridle.service &>/dev/null; then
            msg "$C_GREEN" "  -> Enabled hypridle with the Quickshell lock command."
        else
            msg "$C_YELLOW" "  -> Could not start hypridle now; it will start after login/reboot."
        fi
    fi

    # Waybar and swayidle are session daemons, unlike lockers which only exist
    # while the screen is locked. Never kill an active locker during install.
    pkill -TERM -x waybar 2>/dev/null || true
    pkill -TERM -x swayidle 2>/dev/null || true

    if command -v qs &>/dev/null \
            && [ -n "${WAYLAND_DISPLAY:-}" ] \
            && [ -x "$HOME/.config/quickshell/reload.sh" ]; then
        if "$HOME/.config/quickshell/reload.sh"; then
            msg "$C_GREEN" "  -> Quickshell panels started for the current session."
        else
            msg "$C_YELLOW" "  -> Panels will start automatically after login/reboot."
        fi
    else
        msg "$C_BLUE" "  -> Quickshell panels will start after login/reboot."
    fi

    msg "$C_GREEN" "✅ Waybar and legacy lockscreen migration complete."
    msg "$C_BLUE" "  -> Previous files are recoverable from $BACKUP_DIR"
}

# Function to install fonts
install_fonts() {
    msg "$C_CYAN" "🔤 Installing fonts..."
    local dotfiles_dir
    dotfiles_dir=$(pwd)
    local src="$dotfiles_dir/fonts"
    local dest="$HOME/.local/share/fonts"
    
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        msg "$C_BLUE" "  -> Copying fonts to $dest..."
        cp -r "$src/." "$dest/"
        msg "$C_BLUE" "  -> Updating font cache..."
        fc-cache -f
        msg "$C_GREEN" "✅ Fonts installed and cache updated."
    else
        msg "$C_YELLOW" "⚠️ Fonts directory not found in repo. Skipping."
    fi
}



# Function to set executable permissions for scripts.
set_script_permissions() {
    msg "$C_CYAN" "🔐 Setting executable permissions for scripts..."
    for dir in "${SCRIPT_DIRS[@]}"; do
        local target_dir="$HOME/.config/$dir"
        if [ -d "$target_dir" ]; then
            find "$target_dir" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
            msg "$C_GREEN" "  -> Permissions set for scripts in '$target_dir'."
        fi
    done
}

# Function to build and install fastfetch with GIF support from source.
build_fastfetch_from_source() {
    # Check if fastfetch is already installed to avoid unnecessary rebuilds
    if command -v fastfetch &>/dev/null; then
         msg "$C_GREEN" "✅ fastfetch is already installed."
         return
    fi

    msg "$C_CYAN" "🎞️  Building and installing Fastfetch with GIF support from source..."
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if git clone https://github.com/Maybe4a6f7365/fastfetch-gif-support.git "$temp_dir"; then
        cd "$temp_dir"
        mkdir -p build && cd build
        cmake ..
        make -j"$(nproc)"
        if sudo make install; then
            msg "$C_GREEN" "✅ Fastfetch with GIF support installed successfully."
        else
            msg "$C_RED" "❌ Failed to install fastfetch-gif-support."
        fi
        cd "$HOME"
    else
        msg "$C_RED" "❌ Failed to clone fastfetch-gif-support repository."
    fi
}

# --- MAIN FUNCTION ---
main() {
    # Display banner
    cat <<'BANNER'
                                     __                         __                 
         ______   ______  __                     __            __      ______  __ _
_                   
                                    |  \                       |  \                
        /      \ /      \|  \                   |  \          |  \    /      \|  \ 
 \                  
  ______   ______        __  _______| ▓▓____   ______  __    __| ▓▓____   ______  _
______ |  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\ ▓▓ _______       ____| ▓▓ ______  _| ▓▓_  |  ▓▓▓▓▓▓\\▓▓ 
▓▓ ______   _______ 
 /      \ |      \      |  \/       \ ▓▓    \ |      \|  \  |  \ ▓▓    \ |      \| 
      \ \▓▓__| ▓▓ ▓▓__/ ▓▓\▓ /       \     /      ▓▓/      \|   ▓▓ \ | ▓▓_  \▓▓  \ 
▓▓/      \ /       \
|  ▓▓▓▓▓▓\ \▓▓▓▓▓▓\      \▓▓  ▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓\ \▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓▓▓▓▓▓\ \▓▓▓▓▓▓\ 
▓▓▓▓▓▓\/      ▓▓>▓▓    ▓▓  |  ▓▓▓▓▓▓▓    |  ▓▓▓▓▓▓▓  ▓▓▓▓▓▓\\▓▓▓▓▓▓ | ▓▓ \   | ▓▓ ▓
▓  ▓▓▓▓▓▓\  ▓▓▓▓▓▓▓
| ▓▓   \▓▓/      ▓▓     |  \ ▓▓     | ▓▓  | ▓▓/      ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓/      ▓▓ 
▓▓  | ▓▓  ▓▓▓▓▓▓|  ▓▓▓▓▓▓    \▓▓    \     | ▓▓  | ▓▓ ▓▓  | ▓▓ | ▓▓ __| ▓▓▓▓   | ▓▓ 
▓▓ ▓▓    ▓▓\▓▓    \ 
| ▓▓     |  ▓▓▓▓▓▓▓     | ▓▓ ▓▓_____| ▓▓  | ▓▓  ▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓  | ▓▓  ▓▓▓▓▓▓▓ 
▓▓  | ▓▓ ▓▓_____| ▓▓__/ ▓▓   _\▓▓▓▓▓▓\    | ▓▓__| ▓▓ ▓▓__/ ▓▓ | ▓▓|  \ ▓▓     | ▓▓ 
▓▓ ▓▓▓▓▓▓▓▓_\▓▓▓▓▓▓\
| ▓▓      \▓▓    ▓▓     | ▓▓\▓▓     \ ▓▓  | ▓▓\▓▓    ▓▓\▓▓    ▓▓ ▓▓  | ▓▓\▓▓    ▓▓ 
▓▓  | ▓▓ ▓▓     \▓▓    ▓▓  |       ▓▓     \▓▓    ▓▓\▓▓    ▓▓  \▓▓  ▓▓ ▓▓     | ▓▓ ▓
▓\▓▓     \       ▓▓
 \▓▓       \▓▓▓▓▓▓▓__   | ▓▓ \▓▓▓▓▓▓▓\▓▓   \▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓ \▓▓   \▓▓ \▓▓▓▓▓▓▓\
▓▓   \▓▓\▓▓▓▓▓▓▓▓ \▓▓▓▓▓▓    \▓▓▓▓▓▓▓       \▓▓▓▓▓▓▓ \▓▓▓▓▓▓    \▓▓▓▓ \▓▓      \▓▓\
▓▓ \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ 
                  |  \__/ ▓▓                                                       
                                                                                   
BANNER
    
    msg "$C_GREEN" "🚀 Starting installation of Rajchauhan28's Hyprland Dotfiles..."
    
    detect_legacy_shell_components
    check_aur_helper
    install_packages
    stow_configs
    install_fonts
    set_script_permissions
    activate_quickshell_replacements
    build_fastfetch_from_source
    
    msg "$C_GREEN" "🎉 All tasks completed!"
    
    # Final instructions
    echo
    msg "$C_YELLOW" "IMPORTANT: Please reboot your system for all changes to take effect properly."
    read -rp "Reboot now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        msg "$C_BLUE" "Rebooting now..."
        sudo reboot
    else
        msg "$C_BLUE" "Please remember to reboot your system later."
    fi
}

# --- SCRIPT EXECUTION ---
main "$@"
