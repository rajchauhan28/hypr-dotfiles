#!/bin/bash
#
# ██╗███╗   ██╗████████╗ ██████╗ ██████╗ ██████╗  ██████╗
# ██║████╗  ██║╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝
# ██║██╔██╗ ██║   ██║   ██║   ██║██████╔╝██████╔╝██║     
# ██║██║╚██╗██║   ██║   ██║   ██║██╔══██╗██╔═══╝ ██║     
# ██║██║ ╚████║   ██║   ╚██████╔╝██║  ██║██║     ╚██████╗
# ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝      ╚═════╝
#
# Installer for Reign's Hyprland Dotfiles

set -e # Exit immediately if a command exits with a non-zero status.

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
    waybar
    wlogout
    wofi
    yazi
    ReignShell
)

# Directories containing scripts that need executable permissions
readonly SCRIPT_DIRS=(
    "hypr"
    "waybar/scripts"
)

# --- UTILITY FUNCTIONS ---

# msg <color> <message>
# Prints a message with a specified color.
msg() {
    echo -e "${1}${2}${C_RESET}"
}

# --- CORE FUNCTIONS ---

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
        msg "$C_RED" "❌ Package installation failed. Please check the output for errors."
        exit 1
    fi
    msg "$C_GREEN" "✅ All packages installed successfully."
}

# Function to back up existing configs and copy the new ones.
backup_and_copy_configs() {
    local dotfiles_dir
    dotfiles_dir=$(pwd)
    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    
    msg "$C_CYAN" "📂 Backing up existing configs to $backup_dir and copying new ones..."
    mkdir -p "$backup_dir/.config"
    
    for dir in "${ALL_CONFIG_DIRS[@]}"; do
        local src="$dotfiles_dir/$dir"
        local dest="$HOME/.config/$dir"
        
        if [ -d "$src" ]; then
            if [ -e "$dest" ]; then
                msg "$C_YELLOW" "  -> Backing up '$dir'..."
                mv "$dest" "$backup_dir/.config/"
            fi
            msg "$C_BLUE" "  -> Installing '$dir'..."
            cp -r "$src" "$HOME/.config/"
        else
            msg "$C_YELLOW" "⚠️ Source directory '$src' not found in repo. Skipping."
        fi
    done
    
    # Handle wallpapers separately
    if [ -d "$dotfiles_dir/wallpapers" ]; then
        msg "$C_BLUE" "  -> Installing wallpapers..."
        mkdir -p "$HOME/Pictures/wallpapers"
        cp -r "$dotfiles_dir/wallpapers/." "$HOME/Pictures/wallpapers/"
    fi
    
    msg "$C_GREEN" "✅ Config files and wallpapers installed."
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

# Function to install zshrc
install_zshrc() {
    msg "$C_CYAN" "🐚 Installing .zshrc..."
    local dotfiles_dir
    dotfiles_dir=$(pwd)
    local src="$dotfiles_dir/.zshrc"
    local dest="$HOME/.zshrc"
    
    if [ -f "$src" ]; then
        if [ -f "$dest" ]; then
             local backup_path="$HOME/.zshrc.backup_$(date +%Y%m%d_%H%M%S)"
             msg "$C_YELLOW" "  -> Backing up existing .zshrc to $backup_path"
             mv "$dest" "$backup_path"
        fi
        msg "$C_BLUE" "  -> Copying .zshrc..."
        cp "$src" "$dest"
        msg "$C_GREEN" "✅ .zshrc installed."
    else
        msg "$C_YELLOW" "⚠️ .zshrc not found in repo. Skipping."
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
    
    msg "$C_GREEN" "🚀 Starting installation of Reign's Hyprland Dotfiles..."
    
    check_aur_helper
    install_packages
    backup_and_copy_configs
    install_fonts
    install_zshrc
    set_script_permissions
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
