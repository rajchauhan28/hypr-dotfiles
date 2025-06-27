#!/bin/bash

# ASCII Art Banner
cat <<'EOF'
                                     __                         __                          ______   ______  __                     __            __      ______  __ __                   
                                    |  \                       |  \                        /      \ /      \|  \                   |  \          |  \    /      \|  \  \                  
  ______   ______        __  _______| ▓▓____   ______  __    __| ▓▓____   ______  _______ |  ▓▓▓▓▓▓\  ▓▓▓▓▓▓\ ▓▓ _______       ____| ▓▓ ______  _| ▓▓_  |  ▓▓▓▓▓▓\\▓▓ ▓▓ ______   _______ 
 /      \ |      \      |  \/       \ ▓▓    \ |      \|  \  |  \ ▓▓    \ |      \|       \ \▓▓__| ▓▓ ▓▓__/ ▓▓\▓ /       \     /      ▓▓/      \|   ▓▓ \ | ▓▓_  \▓▓  \ ▓▓/      \ /       \
|  ▓▓▓▓▓▓\ \▓▓▓▓▓▓\      \▓▓  ▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓\ \▓▓▓▓▓▓\ ▓▓  | ▓▓ ▓▓▓▓▓▓▓\ \▓▓▓▓▓▓\ ▓▓▓▓▓▓▓\/      ▓▓>▓▓    ▓▓  |  ▓▓▓▓▓▓▓    |  ▓▓▓▓▓▓▓  ▓▓▓▓▓▓\\▓▓▓▓▓▓ | ▓▓ \   | ▓▓ ▓▓  ▓▓▓▓▓▓\  ▓▓▓▓▓▓▓
| ▓▓   \▓▓/      ▓▓     |  \ ▓▓     | ▓▓  | ▓▓/      ▓▓ ▓▓  | ▓▓ ▓▓  | ▓▓/      ▓▓ ▓▓  | ▓▓  ▓▓▓▓▓▓|  ▓▓▓▓▓▓    \▓▓    \     | ▓▓  | ▓▓ ▓▓  | ▓▓ | ▓▓ __| ▓▓▓▓   | ▓▓ ▓▓ ▓▓    ▓▓\▓▓    \ 
| ▓▓     |  ▓▓▓▓▓▓▓     | ▓▓ ▓▓_____| ▓▓  | ▓▓  ▓▓▓▓▓▓▓ ▓▓__/ ▓▓ ▓▓  | ▓▓  ▓▓▓▓▓▓▓ ▓▓  | ▓▓ ▓▓_____| ▓▓__/ ▓▓   _\▓▓▓▓▓▓\    | ▓▓__| ▓▓ ▓▓__/ ▓▓ | ▓▓|  \ ▓▓     | ▓▓ ▓▓ ▓▓▓▓▓▓▓▓_\▓▓▓▓▓▓\
| ▓▓      \▓▓    ▓▓     | ▓▓\▓▓     \ ▓▓  | ▓▓\▓▓    ▓▓\▓▓    ▓▓ ▓▓  | ▓▓\▓▓    ▓▓ ▓▓  | ▓▓ ▓▓     \\▓▓    ▓▓  |       ▓▓     \▓▓    ▓▓\▓▓    ▓▓  \▓▓  ▓▓ ▓▓     | ▓▓ ▓▓\▓▓     \       ▓▓
 \▓▓       \▓▓▓▓▓▓▓__   | ▓▓ \▓▓▓▓▓▓▓\▓▓   \▓▓ \▓▓▓▓▓▓▓ \▓▓▓▓▓▓ \▓▓   \▓▓ \▓▓▓▓▓▓▓\▓▓   \▓▓\▓▓▓▓▓▓▓▓ \▓▓▓▓▓▓    \▓▓▓▓▓▓▓       \▓▓▓▓▓▓▓ \▓▓▓▓▓▓    \▓▓▓▓ \▓▓      \▓▓\▓▓ \▓▓▓▓▓▓▓\▓▓▓▓▓▓▓ 
                  |  \__/ ▓▓                                                                                                                                                              
                   \▓▓    ▓▓                                                                                                                                                              
                    \▓▓▓▓▓▓                                                                                                                                                               
                                                            
                                      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
                                      ██ ██ █ ██ █▀▄▄▀█ ▄▄▀█ ██ ▄▄▀█ ▄▄▀█ ▄▀████ ▄▄▀█▀▄▄▀█▄ ▄█ ▄▄██▄██ ▄▄█ ██ ▄▄████▄██ ▄▄▀█ ▄▄█▄ ▄█ ▄▄▀█ ██ ██ ▄▄█ ▄▄▀
                                      ██ ▄▄ █ ▀▀ █ ▀▀ █ ▀▀▄█ ██ ▀▀ █ ██ █ █ ████ ██ █ ██ ██ ██ ▄███ ▄█ ▄▄█ ██▄▄▀████ ▄█ ██ █▄▄▀██ ██ ▀▀ █ ██ ██ ▄▄█ ▀▀▄
                                      ██ ██ █▀▀▀▄█ ████▄█▄▄█▄▄█▄██▄█▄██▄█▄▄█████ ▀▀ ██▄▄███▄██▄███▄▄▄█▄▄▄█▄▄█▄▄▄███▄▄▄█▄██▄█▄▄▄██▄██▄██▄█▄▄█▄▄█▄▄▄█▄█▄▄
                                      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

EOF

# All available modules
ALL_CONFIG_DIRS=(
    dunst
    hypr
    rofi
    swaync
    wal
    waybar
    wezterm
    wlogout
    wofi
)

INSTALL_MODULES=("${ALL_CONFIG_DIRS[@]}")  # default to all

# Parse --only flag
if [[ "$1" == "--only" ]]; then
    shift
    if [ $# -eq 0 ]; then
        echo "❌ Error: '--only' requires at least one module name."
        echo "🧩 Available modules: ${ALL_CONFIG_DIRS[*]}"
        exit 1
    fi
    INSTALL_MODULES=()
    for arg in "$@"; do
        if [[ " ${ALL_CONFIG_DIRS[*]} " =~ " $arg " ]]; then
            INSTALL_MODULES+=("$arg")
        else
            echo "⚠️  Warning: '$arg' is not a known module. Skipping."
        fi
    done
    if [ ${#INSTALL_MODULES[@]} -eq 0 ]; then
        echo "❌ No valid modules provided. Aborting."
        exit 1
    fi
fi

BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
DOTFILES_DIR="$(pwd)"

echo "🔄 Backing up and installing modules: ${INSTALL_MODULES[*]}"
mkdir -p "$BACKUP_DIR"

for dir in "${INSTALL_MODULES[@]}"; do
    src="$DOTFILES_DIR/$dir"
    dest="$HOME/.config/$dir"
    
    if [ -e "$dest" ]; then
        echo "📦 Backing up $dest to $BACKUP_DIR"
        mkdir -p "$(dirname "$BACKUP_DIR/.config/$dir")"
        mv "$dest" "$BACKUP_DIR/.config/"
    fi

    echo "📂 Installing $dir"
    cp -r "$src" "$HOME/.config/"
done

# Wallpapers: always install unless --only excludes them
if [[ ! "$*" == *"--only"* ]] || [[ " ${INSTALL_MODULES[*]} " =~ " wallpapers " ]]; then
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        echo "🖼️  Installing wallpapers..."
        mkdir -p "$HOME/Pictures/wallpapers"
        cp -r "$DOTFILES_DIR/wallpapers/." "$HOME/Pictures/wallpapers/"
    fi
fi

# Hyprpm setup
if [[ " ${INSTALL_MODULES[*]} " =~ " hypr " ]]; then
    echo "🧩 Setting up Hyprpm..."
    if ! command -v hyprpm &>/dev/null; then
        echo "❌ hyprpm not installed. Skipping Hyprspace setup."
    else
        HYPRSPACE_REPO="https://github.com/KZDKM/Hyprspace"

        echo "➕ Adding Hyprspace plugin"
        hyprpm add "$HYPRSPACE_REPO"

        echo "🔄 Updating plugins"
        hyprpm update

        echo "✅ Enabling Hyprspace plugin"
        if systemctl --user is-active hyprland &>/dev/null; then
            systemd-run --user --scope hyprpm enable Hyprspace
        else
            XDG_RUNTIME_DIR="/run/user/$(id -u)" hyprpm enable Hyprspace
        fi
    fi
fi

read -rp "🔁 Reload Hyprland now? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    hyprctl reload
    echo "✅ Hyprland reloaded."
else
    echo "ℹ️  Skipped reload. Please reload manually."
fi

#fastfetch gif support addition working only with vulkun supported terminals like kitty, wezterm, etc.
echo "🎞️  Installing Fastfetch with GIF support..."
cd "$HOME" || exit

if [ -d "fastfetch-gif-support" ]; then
    echo "🧹 Removing existing fastfetch-gif-support directory"
    rm -rf fastfetch-gif-support
fi

git clone https://github.com/Maybe4a6f7365/fastfetch-gif-support.git
cd fastfetch-gif-support || exit
mkdir build && cd build || exit

cmake ..
make -j"$(nproc)"

echo "🔐 Installing fastfetch (may require sudo)..."
sudo make install

cd "$HOME"
rm -rf fastfetch-gif-support
echo "✅ Fastfetch with GIF support installed!"

echo "🎉 Dotfiles installation complete!"
