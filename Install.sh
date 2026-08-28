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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

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

# Notification daemons. The Quickshell suite registers its own
# org.freedesktop.Notifications server (notifications/NotificationsPanel.qml);
# a second daemon claims the same bus name, and whichever loses simply never
# receives a notification again.
readonly -a LEGACY_NOTIFIERS=(
    swaync
    mako
    dunst
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
    for component in waybar swayidle "${LEGACY_NOTIFIERS[@]}" "${LEGACY_LOCKERS[@]}"; do
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
                swaync*.service|mako*.service|dunst*.service|\
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
            if grep -Eqi '^[[:space:]]*Exec(Start|StartPre)=.*(waybar|swayidle|swaync|mako|dunst|hyprlock|swaylock|gtklock|waylock|i3lock|xsecurelock|betterlockscreen|physlock)' "$unit_file"; then
                append_unique LEGACY_SERVICE_UNITS "$(basename "$unit_file")"
            fi
        done < <(find "$user_unit_dir" -maxdepth 1 -type f -name '*.service' -print0 2>/dev/null)
    fi

    local autostart_dir="$HOME/.config/autostart"
    if [ -d "$autostart_dir" ]; then
        local desktop_file
        while IFS= read -r -d '' desktop_file; do
            if grep -Eqi '^[[:space:]]*Exec=.*(waybar|swayidle|swaync|mako|dunst|hyprlock|swaylock|gtklock|waylock|i3lock|xsecurelock|betterlockscreen|physlock)' "$desktop_file"; then
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

# filter_packages_for_hardware <file>
# Emits the package names that apply to THIS machine. A line may end with a
# "# requires:<flag>" tag (nvidia, acer, laptop); untagged lines always apply.
filter_packages_for_hardware() {
    local file="$1" line pkg tag
    while IFS= read -r line; do
        # Strip comments only when they are a trailing annotation, so a
        # whole-line comment still drops out.
        case "$line" in
            \#*|"") continue ;;
        esac

        tag=""
        if printf '%s' "$line" | grep -q '#[[:space:]]*requires:'; then
            tag="$(printf '%s' "$line" | sed -n 's/.*#[[:space:]]*requires:[[:space:]]*\([a-z-]*\).*/\1/p')"
        fi
        pkg="$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//' | tr -d '[:space:]')"
        if [ -z "$pkg" ]; then
            continue
        fi

        # Plain `if`s, not `test && printf`: this runs under `set -e` inside a
        # process substitution, where a false test would abort the subshell and
        # silently truncate the package list on the first non-matching tag.
        case "$tag" in
            nvidia)
                if [ "$HW_GPU_NVIDIA" = 1 ]; then printf '%s\n' "$pkg"; fi ;;
            acer)
                if [ "$HW_ACER_GAMING" = 1 ]; then printf '%s\n' "$pkg"; fi ;;
            laptop)
                if [ "$HW_LAPTOP" = 1 ]; then printf '%s\n' "$pkg"; fi ;;
            *)
                printf '%s\n' "$pkg" ;;
        esac
    done < "$file"
    return 0
}

# Function to install packages from package_list.txt
install_packages() {
    msg "$C_CYAN" "📦 Reading package list and installing packages..."
    local package_file="package_list.txt"
    if [ ! -f "$package_file" ]; then
        msg "$C_YELLOW" "⚠️ $package_file not found. Skipping package installation."
        return
    fi
    
    # Lines may carry a "# requires:<flag>" tag; those install only on
    # matching hardware, so an AMD desktop never pulls in envycontrol.
    mapfile -t PACKAGES < <(filter_packages_for_hardware "$package_file")
    
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
    for legacy_config in waybar swayidle "${LEGACY_NOTIFIERS[@]}" "${LEGACY_LOCKERS[@]}"; do
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
    # Absolute, so this keeps working wherever an earlier step left the cwd.
    ( cd "$REPO_DIR/stow_base" && stow -t "$HOME" . )
    
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

        # The AuraLink Bluetooth auto-connect daemon is installed and enabled
        # by auralink's own install.sh (see offer_auralink). All that is left
        # here is to switch it off on a machine with no radio, where it would
        # poll forever with nothing to find.
        if [ "$HW_BLUETOOTH" != 1 ] \
                && systemctl --user is-enabled auralink-bt-daemon.service &>/dev/null; then
            systemctl --user disable --now auralink-bt-daemon.service &>/dev/null || true
            msg "$C_BLUE" "  -> No Bluetooth adapter: auto-connect daemon disabled."
        fi
    fi

    # Waybar and swayidle are session daemons, unlike lockers which only exist
    # while the screen is locked. Never kill an active locker during install.
    pkill -TERM -x waybar 2>/dev/null || true
    pkill -TERM -x swayidle 2>/dev/null || true

    # Free the notification bus name before the Quickshell shell starts, or it
    # comes up without a notification server and every notify-send is lost.
    local notifier
    for notifier in "${LEGACY_NOTIFIERS[@]}"; do
        pkill -TERM -x "$notifier" 2>/dev/null || true
    done

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

# Refresh the font cache for the fonts stow just linked.
#
# This used to look for a top-level `fonts/` directory that does not exist in
# this repository -- the fonts live in stow_base/.local/share/fonts and arrive
# via stow -- so it printed "Skipping" every run and fc-cache never ran. New
# installs then had a shell referencing fonts fontconfig had not indexed.
install_fonts() {
    msg "$C_CYAN" "🔤 Refreshing font cache..."
    local dest="$HOME/.local/share/fonts"

    if [ ! -d "$dest" ]; then
        msg "$C_YELLOW" "⚠️ $dest not present; skipping font cache refresh."
        return
    fi

    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$dest" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
        msg "$C_GREEN" "✅ Font cache updated."
    else
        msg "$C_YELLOW" "⚠️ fc-cache not found; fonts may not appear until next login."
    fi
}

# Function to set executable permissions for scripts.
#
# Walks the installed config tree instead of the old hand-kept SCRIPT_DIRS
# list, which had drifted: quickshell/widgets, quickshell/notifications and
# hypr/lib all ship scripts and none of them were in it, so those arrived
# non-executable on a fresh install.
set_script_permissions() {
    msg "$C_CYAN" "🔐 Setting executable permissions for scripts..."
    local dir
    for dir in "${ALL_CONFIG_DIRS[@]}"; do
        local target_dir="$HOME/.config/$dir"
        if [ -d "$target_dir" ]; then
            find -L "$target_dir" -type f \( -name "*.sh" -o -name "*.py" \) \
                -exec chmod +x {} + 2>/dev/null || true
        fi
    done
    if [ -d "$HOME/.local/bin" ]; then
        find -L "$HOME/.local/bin" -maxdepth 1 -type f -exec chmod +x {} + 2>/dev/null || true
    fi
    msg "$C_GREEN" "  -> Permissions set."
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

# --- HARDWARE DETECTION ---
#
# Everything vendor-specific in this repository was written on an Acer Predator
# with an Intel + NVIDIA Optimus GPU. None of it may be forced onto a machine
# that is not one. These flags are the single source of truth for that, and
# they are written out to ~/.config/hypr/hardware.{conf,lua} so the Hyprland
# config gates on exactly the same facts.
#
# Note on style: this script runs under `set -e`, where a bare `test ... && x=1`
# aborts the whole install the moment the test is false. Every check below is
# therefore a real `if`, never a short-circuit at statement level.
HW_VENDOR=""
HW_PRODUCT=""
HW_ACER_GAMING=0     # Acer Predator / Nitro -- the only models DAMX supports
HW_GPU_NVIDIA=0
HW_IGPU=""           # "intel", "amd", or empty
HW_BATTERY=0
HW_LAPTOP=0
HW_BLUETOOTH=0

detect_hardware() {
    msg "$C_CYAN" "🖥️  Detecting hardware..."

    HW_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    HW_PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    # Match the product string, not just the vendor: an Acer Aspire has no
    # turbo key and no predator_sense/nitro_sense sysfs nodes.
    if printf '%s' "$HW_VENDOR" | grep -qi 'acer' \
            && printf '%s' "$HW_PRODUCT" | grep -qiE 'predator|nitro|helios|triton|PHN|PH[0-9]|AN[0-9]'; then
        HW_ACER_GAMING=1
    fi

    # PCI vendor IDs are stable where marketing names are not:
    # 10de = NVIDIA, 8086 = Intel, 1002/1022 = AMD.
    if command -v lspci &>/dev/null; then
        local gpus
        gpus="$(lspci -nn 2>/dev/null | grep -Ei 'vga compatible|3d controller|display controller' || true)"
        if printf '%s' "$gpus" | grep -q '\[10de:'; then
            HW_GPU_NVIDIA=1
        fi
        if printf '%s' "$gpus" | grep -q '\[8086:'; then
            HW_IGPU="intel"
        elif printf '%s' "$gpus" | grep -qE '\[100[24]:'; then
            HW_IGPU="amd"
        fi
    else
        # pciutils only arrives with the package install, so on a first run
        # fall back to the loaded DRM drivers. That is enough to pick a
        # VA-API driver correctly.
        if [ -d /sys/module/nvidia ]; then
            HW_GPU_NVIDIA=1
        fi
        if [ -d /sys/module/i915 ] || [ -d /sys/module/xe ]; then
            HW_IGPU="intel"
        elif [ -d /sys/module/amdgpu ] || [ -d /sys/module/radeon ]; then
            HW_IGPU="amd"
        fi
    fi

    local supply
    for supply in /sys/class/power_supply/*; do
        [ -e "$supply/type" ] || continue
        if [ "$(cat "$supply/type" 2>/dev/null || true)" = "Battery" ]; then
            HW_BATTERY=1
            break
        fi
    done

    # DMI chassis types 8-11 and 14 are the portable/laptop/notebook family.
    local chassis
    chassis="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)"
    case "$chassis" in
        8|9|10|11|14) HW_LAPTOP=1 ;;
    esac
    if [ "$HW_BATTERY" = 1 ]; then
        HW_LAPTOP=1
    fi

    # Bluetooth: the auralink auto-connect daemon is pointless without a radio.
    if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null || true)" ]; then
        HW_BLUETOOTH=1
    elif lsusb 2>/dev/null | grep -qi bluetooth; then
        HW_BLUETOOTH=1
    fi

    local nv_label="no" bat_label="no" chassis_label="desktop"
    if [ "$HW_GPU_NVIDIA" = 1 ]; then nv_label="yes"; fi
    if [ "$HW_BATTERY" = 1 ]; then bat_label="yes"; fi
    if [ "$HW_LAPTOP" = 1 ]; then chassis_label="laptop"; fi

    msg "$C_BLUE" "  -> Machine : ${HW_VENDOR:-unknown} ${HW_PRODUCT:-unknown}"
    msg "$C_BLUE" "  -> GPU     : iGPU=${HW_IGPU:-none} NVIDIA=$nv_label"
    local bt_label="no"
    if [ "$HW_BLUETOOTH" = 1 ]; then bt_label="yes"; fi
    msg "$C_BLUE" "  -> Chassis : $chassis_label (battery=$bat_label, bluetooth=$bt_label)"
    if [ "$HW_ACER_GAMING" = 1 ]; then
        msg "$C_GREEN" "  -> Acer Predator/Nitro: turbo key and DAMX driver kept."
    else
        msg "$C_BLUE" "  -> Not an Acer Predator/Nitro: DAMX driver and turbo key skipped."
    fi
    if [ "$HW_GPU_NVIDIA" != 1 ]; then
        msg "$C_BLUE" "  -> No NVIDIA GPU: envycontrol and GPU-switching entries skipped."
    fi
}

# lua_escape <string> -- make a value safe inside a Lua double-quoted string.
# DMI strings are vendor-supplied and have contained quotes and backslashes.
lua_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\n'
}

# Write the profile the Hyprland configs read. Both formats carry the same
# facts because hyprland.lua (v0.55+) and hyprland.conf are both shipped.
write_hardware_profile() {
    msg "$C_CYAN" "🧩 Writing hardware profile for Hyprland..."
    local hypr_dir="$HOME/.config/hypr"
    mkdir -p "$hypr_dir"

    # Generated per machine: never a symlink into the repository, or the next
    # `git pull` would fight the installer.
    rm -f "$hypr_dir/hardware.conf" "$hypr_dir/hardware.lua"

    {
        echo "# Generated by Install.sh on $(date -Iseconds) -- do not edit."
        echo "# Machine: ${HW_VENDOR:-unknown} ${HW_PRODUCT:-unknown}"
        echo
        case "$HW_IGPU" in
            intel) echo "env = LIBVA_DRIVER_NAME,iHD" ;;
            amd)   echo "env = LIBVA_DRIVER_NAME,radeonsi" ;;
            *)
                if [ "$HW_GPU_NVIDIA" = 1 ]; then
                    echo "env = LIBVA_DRIVER_NAME,nvidia"
                    echo "env = GBM_BACKEND,nvidia-drm"
                    echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
                fi
                ;;
        esac
        if [ "$HW_GPU_NVIDIA" = 1 ]; then
            echo "env = NVD_BACKEND,direct"
        fi
        echo
        if [ "$HW_ACER_GAMING" = 1 ]; then
            echo "# Predator/Nitro turbo key."
            echo "bindl = , XF86Launch1, exec, DAMX"
        fi
        if [ "$HW_BATTERY" = 1 ]; then
            echo "# AC/battery refresh-rate and governor tuning."
            echo "exec-once = \$HOME/.config/hypr/smart_gpu.py"
        fi
    } > "$hypr_dir/hardware.conf"

    local lua_acer="false" lua_nvidia="false" lua_battery="false" lua_laptop="false" lua_igpu="false"
    if [ "$HW_ACER_GAMING" = 1 ]; then lua_acer="true"; fi
    if [ "$HW_GPU_NVIDIA" = 1 ]; then lua_nvidia="true"; fi
    if [ "$HW_BATTERY" = 1 ]; then lua_battery="true"; fi
    if [ "$HW_LAPTOP" = 1 ]; then lua_laptop="true"; fi
    if [ -n "$HW_IGPU" ]; then lua_igpu="\"$HW_IGPU\""; fi

    {
        echo "-- Generated by Install.sh on $(date -Iseconds) -- do not edit."
        echo "return {"
        # %q is SHELL quoting, not Lua -- it emits bare words and backslash
        # escapes that make the file a syntax error, which pcall() would then
        # swallow into an empty profile. Quote for Lua explicitly.
        printf '    vendor      = "%s",\n' "$(lua_escape "${HW_VENDOR:-unknown}")"
        printf '    product     = "%s",\n' "$(lua_escape "${HW_PRODUCT:-unknown}")"
        echo "    acer_gaming = $lua_acer,"
        echo "    gpu_nvidia  = $lua_nvidia,"
        echo "    igpu        = $lua_igpu,"
        echo "    battery     = $lua_battery,"
        echo "    laptop      = $lua_laptop,"
        echo "}"
    } > "$hypr_dir/hardware.lua"

    msg "$C_GREEN" "✅ Hardware profile written to $hypr_dir/hardware.{conf,lua}"
}

# The Acer turbo key needs the DAMX suite (PXDiv/Div-Acer-Manager-Max), a GPL-3
# kernel module that is deliberately NOT vendored here: it would freeze at a
# snapshot and mix GPL-3 into an MIT repository. Offer the upstream installer
# instead, and only on hardware it supports.
#
# It is never run unattended. It builds and loads a kernel module and needs
# root, so it stays an explicit opt-in even inside an installer the user
# already trusted.
offer_acer_driver() {
    if [ "$HW_ACER_GAMING" != 1 ]; then
        return
    fi
    if command -v DAMX &>/dev/null; then
        msg "$C_GREEN" "✅ DAMX is already installed; the turbo key will work."
        return
    fi

    msg "$C_CYAN" "🔧 Acer Predator/Nitro detected."
    msg "$C_BLUE" "  -> The XF86Launch1 turbo key needs the DAMX suite, which builds and"
    msg "$C_BLUE" "     loads an acer-wmi kernel module and requires root."
    msg "$C_BLUE" "     Upstream: https://github.com/PXDiv/Div-Acer-Manager-Max"

    if [ ! -t 0 ]; then
        msg "$C_YELLOW" "  -> Not an interactive terminal; skipping. Install it later with:"
        msg "$C_BLUE"   "     curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/remote-setup.sh | bash"
        return
    fi

    local answer
    read -rp "  Install the DAMX suite now? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        msg "$C_BLUE" "  -> Skipped. The turbo key binding stays inert until DAMX is installed."
        return
    fi

    if curl -sSL https://raw.githubusercontent.com/PXDiv/Div-Acer-Manager-Max/main/remote-setup.sh | bash; then
        msg "$C_GREEN" "✅ DAMX suite installed."
    else
        msg "$C_YELLOW" "⚠️  DAMX install failed; the turbo key will not work until it succeeds."
    fi
}

# --- TEMPLATES AND PER-USER STATE ---

# Render the *.in templates that no config format can expand for itself.
# .desktop Exec= lines in particular are NOT shell-expanded, so "$HOME/..."
# there would simply not launch.
render_templates() {
    msg "$C_CYAN" "📝 Rendering templates for this user..."
    local template target rendered=0
    while IFS= read -r -d '' template; do
        target="$HOME/${template#"$REPO_DIR/stow_base/"}"
        target="${target%.in}"
        mkdir -p "$(dirname "$target")"
        # Remove any symlink first. An earlier version of this repository
        # stowed these files directly, so upgrading leaves a symlink pointing
        # at the now-renamed .in -- and `>` follows a symlink, which would
        # write the rendered output back INTO the repository instead of $HOME.
        if [ -L "$target" ]; then
            rm -f "$target"
        fi
        sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$template" > "$target"
        rendered=$((rendered + 1))
    done < <(find "$REPO_DIR/stow_base" -type f -name '*.in' -print0)
    msg "$C_GREEN" "✅ Rendered $rendered template(s)."

    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" &>/dev/null || true
    fi
}

# Seed the per-user state files. These are gitignored on purpose: they are
# rewritten by the Settings app at runtime, so shipping them tracked would mean
# every `git pull` fighting the user's own choices.
seed_user_state() {
    msg "$C_CYAN" "🌱 Seeding per-user configuration..."
    local default target seeded=0 kept=0
    while IFS= read -r -d '' default; do
        target="$HOME/${default#"$REPO_DIR/stow_base/"}"
        target="${target%.default}"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            kept=$((kept + 1))
            continue
        fi
        mkdir -p "$(dirname "$target")"
        rm -f "$target"
        sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$default" > "$target"
        seeded=$((seeded + 1))
    done < <(find "$REPO_DIR/stow_base" -type f -name '*.default' -print0)
    msg "$C_GREEN" "✅ Seeded $seeded file(s); kept $kept existing user file(s)."
}

# The wallpaper palette (wallust/pywal) is generated at runtime, but
# hyprland.conf `source`s it at parse time and hypridle reads it in its
# notification commands. On a fresh install the directory does not exist yet,
# so Hyprland logs a config error on every startup until the first wallpaper
# is applied. Seed empty files: whatever generates the palette later simply
# overwrites them.
seed_optional_caches() {
    msg "$C_CYAN" "🎨 Seeding placeholder colour cache..."
    local wal_dir="$HOME/.cache/wal"
    mkdir -p "$wal_dir"

    local stub
    for stub in colors-hyprland.conf colors.sh; do
        if [ ! -e "$wal_dir/$stub" ]; then
            printf '# Placeholder written by Install.sh. Replaced the first time\n# a wallpaper is applied.\n' > "$wal_dir/$stub"
        fi
    done
    if [ ! -e "$wal_dir/colors.json" ]; then
        printf '{}\n' > "$wal_dir/colors.json"
    fi
    msg "$C_GREEN" "✅ Colour cache placeholders in place."
}

# AuraLink is the Wi-Fi/Bluetooth manager the sidepanel and the app menu launch.
#
# Its two binaries used to be committed to this repository -- 23 MB of stripped
# x86-64 ELF that went stale silently and could not work on another
# architecture. Build them from source instead, which also installs and enables
# the Bluetooth auto-connect systemd unit via auralink's own install.sh.
#
# Never unattended: a Rust build is minutes of CPU and a large crate download,
# so it stays an explicit opt-in.
readonly AURALINK_REPO="https://github.com/rajchauhan28/auralink.git"

offer_auralink() {
    local src_dir="$HOME/.local/src/auralink"

    if command -v auralink-bt &>/dev/null && [ -x "$HOME/.local/bin/auralink" ]; then
        msg "$C_GREEN" "✅ AuraLink is already installed."
        return
    fi

    msg "$C_CYAN" "📡 AuraLink (Wi-Fi + Bluetooth manager) is not installed."
    if ! command -v cargo &>/dev/null; then
        msg "$C_YELLOW" "  -> cargo not found; skipping. Install rustup, then run:"
        msg "$C_BLUE"   "     git clone $AURALINK_REPO && cd auralink && cargo build --release && ./install.sh"
        return
    fi

    if [ ! -t 0 ]; then
        msg "$C_YELLOW" "  -> Not an interactive terminal; skipping the AuraLink build."
        return
    fi

    local answer
    read -rp "  Build and install AuraLink from source now? (~3 min) [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        msg "$C_BLUE" "  -> Skipped. The sidepanel's network button stays inert until it is installed."
        return
    fi

    mkdir -p "$(dirname "$src_dir")"
    if [ -d "$src_dir/.git" ]; then
        msg "$C_BLUE" "  -> Updating $src_dir..."
        git -C "$src_dir" pull --ff-only || msg "$C_YELLOW" "  -> Could not update; building the checkout as-is."
    else
        msg "$C_BLUE" "  -> Cloning into $src_dir..."
        if ! git clone --depth=1 "$AURALINK_REPO" "$src_dir"; then
            msg "$C_RED" "  ❌ Clone failed; skipping AuraLink."
            return
        fi
    fi

    msg "$C_BLUE" "  -> Building (this takes a few minutes)..."
    if ( cd "$src_dir" && cargo build --release && ./install.sh ); then
        msg "$C_GREEN" "✅ AuraLink installed; Bluetooth auto-connect daemon enabled."
    else
        msg "$C_YELLOW" "⚠️  AuraLink build or install failed; the rest of the shell is unaffected."
    fi
}

# --- SCREEN-AWARE SCALING ---
#
# Every pixel value in settings.json was hand-tuned on a 1920x1200 laptop
# panel. On a 1366x768 screen the 720px-tall dashboard does not fit; on a 4K
# screen at scale 1 the whole shell is half the size it should be. Detect the
# real screen and rescale those values once, at install time. The Settings app
# (Super+comma) still edits every one of them afterwards.
SCREEN_W=0
SCREEN_H=0
SCREEN_SCALE=1

detect_screen() {
    msg "$C_CYAN" "📐 Detecting screen geometry..."

    # 1. A running Hyprland is the best source: it knows the fractional scale
    #    the user actually has applied.
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
            && command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
        local geometry
        geometry="$(hyprctl monitors -j 2>/dev/null | jq -r '
            (map(select(.focused)) | first) // (first) //empty
            | "\(.width) \(.height) \(.scale // 1)"' 2>/dev/null || true)"
        if [ -n "$geometry" ]; then
            read -r SCREEN_W SCREEN_H SCREEN_SCALE <<<"$geometry"
        fi
    fi

    # 2. Installing from a TTY is normal. DRM sysfs reports the preferred mode
    #    of every connected output with no compositor running at all.
    if [ "${SCREEN_W:-0}" -eq 0 ] 2>/dev/null; then
        local card mode
        for card in /sys/class/drm/card*-*/; do
            [ -r "$card/status" ] || continue
            [ "$(cat "$card/status" 2>/dev/null || true)" = "connected" ] || continue
            mode="$(head -1 "$card/modes" 2>/dev/null || true)"
            if printf '%s' "$mode" | grep -qE '^[0-9]+x[0-9]+'; then
                SCREEN_W="${mode%%x*}"
                SCREEN_H="${mode##*x}"
                SCREEN_SCALE=1
                break
            fi
        done
    fi

    if [ "${SCREEN_W:-0}" -eq 0 ] 2>/dev/null; then
        msg "$C_YELLOW" "⚠️  Could not detect a screen; keeping the shipped 1920x1200 geometry."
        msg "$C_BLUE"   "  -> Retune it any time from the Settings app (Super+comma)."
        return 1
    fi

    msg "$C_BLUE" "  -> Screen: ${SCREEN_W}x${SCREEN_H} at scale ${SCREEN_SCALE}"
    return 0
}

scale_shell_to_screen() {
    if ! detect_screen; then
        return 0
    fi
    if ! command -v python3 &>/dev/null; then
        msg "$C_YELLOW" "⚠️  python3 not available; skipping geometry scaling."
        return 0
    fi

    msg "$C_CYAN" "🎚️  Scaling the Quickshell suite to this screen..."
    if SCREEN_W="$SCREEN_W" SCREEN_H="$SCREEN_H" SCREEN_SCALE="$SCREEN_SCALE" \
            python3 "$REPO_DIR/scripts/scale_settings.py" \
                "$HOME/.config/quickshell/settings.json"; then
        msg "$C_GREEN" "✅ Panel geometry scaled for ${SCREEN_W}x${SCREEN_H}."
    else
        msg "$C_YELLOW" "⚠️  Scaling failed; the shipped geometry is still in place."
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
    
    # Hardware first: install_packages filters on these flags, and every later
    # step needs to know what this machine actually is.
    detect_hardware
    detect_legacy_shell_components
    check_aur_helper
    install_packages
    stow_configs
    # Templates and defaults come straight after stow so that the rendered
    # files replace stow's symlinks rather than the other way round.
    render_templates
    seed_user_state
    seed_optional_caches
    write_hardware_profile
    offer_acer_driver
    # Scaling reads the seeded settings.json, so it must follow seed_user_state.
    scale_shell_to_screen
    offer_auralink
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
