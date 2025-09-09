#!/bin/bash
set -euo pipefail

# ========== ASCII Art Banner ==========
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


# ========== CONFIG ==========
ALL_CONFIG_DIRS=(
    ghostty 
    hypr
    rofi
    swaync
    wal
    waybar
    wezterm
    wlogout
    wofi
)

INSTALL_MODULES=("${ALL_CONFIG_DIRS[@]}") # default to all
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
DOTFILES_DIR="$(pwd)"

# ========== PACKAGE LIST ==========
PACKAGES=(
    7zip alsa-utils baobab base base-devel bluez bluez-obex bluez-utils
    brave-bin brightnessctl btop chafa cmake cpio debtap dialog dolphin
    envycontrol eza fastfetch fzf gdb git gnome-keyring gwenview hypridle
    hyprland hyprlock hyprshot iwd jq kamoso kdeconnect kdialog libc++
    libreoffice-fresh libsoup linux linux-firmware linux-headers man-db
    micro mpvpaper nano neovim networkmanager ntfs-3g octopi os-prober
    p7zip-gui pacman partitionmanager paru pavucontrol pipewire-pulse
    polkit-gnome polkit-kde-agent poppler pulsemixer python-dbus
    python-distro python-jinja python-pip python-pydbus python-pyopenssl
    python-systemd qt5-graphicaleffects qt5-multimedia qt5-quickcontrols
    qt5-tools rate-mirrors reflector repgrep resvg sddm seahorse
    sof-firmware starship strace sudo swaync thunar tigervnc tree
    ttf-firacode-nerd ttf-jetbrains-mono-nerd ttf-noto-nerd unzip vi
    visual-studio-code-bin vlc waybar webkit2gtk wget wireguard-tools
    wireplumber wl-clipboard wlogout wofi xclip xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr xed xsel yay zoxide zsh zsh-autosuggestions
    zsh-syntax-highlighting zsh-theme-powerlevel10k-git
)

# ========== Parse Arguments ==========
if [[ "${1-}" == "--only" ]]; then
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

# ========== Backup & Install ==========
echo "🔄 Backing up and installing modules: ${INSTALL_MODULES[*]}"
mkdir -p "$BACKUP_DIR/.config"

for dir in "${INSTALL_MODULES[@]}"; do
    src="$DOTFILES_DIR/$dir"
    dest="$HOME/.config/$dir"

    if [ -e "$dest" ]; then
        echo "📦 Backing up $dest → $BACKUP_DIR/.config/"
        mv "$dest" "$BACKUP_DIR/.config/"
    fi

    echo "📂 Installing $dir"
    cp -r "$src" "$HOME/.config/"
done

# ========== Wallpapers ==========
if [[ ! " $* " =~ "--only" ]] || [[ " ${INSTALL_MODULES[*]} " =~ " wallpapers " ]]; then
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        echo "🖼️  Installing wallpapers..."
        mkdir -p "$HOME/Pictures/wallpapers"
        cp -r "$DOTFILES_DIR/wallpapers/." "$HOME/Pictures/wallpapers/"
    fi
fi

# ========== Hyprpm ==========
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
        XDG_RUNTIME_DIR="/run/user/$(id -u)" hyprpm enable Hyprspace || true
    fi
fi

# ========== Reload Hyprland ==========
if command -v hyprctl &>/dev/null; then
    read -rp "🔁 Reload Hyprland now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        hyprctl reload
        echo "✅ Hyprland reloaded."
    else
        echo "ℹ️  Skipped reload. Please reload manually."
    fi
fi

# ========== Fastfetch with GIF support ==========
echo "🎞️  Installing Fastfetch with GIF support..."
cd "$HOME" || exit

rm -rf fastfetch-gif-support
git clone https://github.com/Maybe4a6f7365/fastfetch-gif-support.git
cd fastfetch-gif-support
mkdir -p build && cd build

cmake ..
make -j"$(nproc)"
sudo make install

cd "$HOME"
rm -rf fastfetch-gif-support
echo "✅ Fastfetch with GIF support installed!"

# ========== Install Arch Packages ==========
echo "📦 Installing required packages..."

# Ensure we have paru or yay
if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
    echo "❌ Neither paru nor yay found. Installing paru..."
    sudo pacman -S --noconfirm --needed base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    pushd /tmp/paru
    makepkg -si --noconfirm
    popd
    rm -rf /tmp/paru
fi

AUR_HELPER=$(command -v paru || command -v yay)

$AUR_HELPER -Syu --noconfirm --needed "${PACKAGES[@]}"

echo "🎉 Dotfiles + packages installation complete!"

