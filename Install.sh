#!/bin/bash
# Install Hyprland and its dependencies on Arch Linux
# This script assumes you have sudo privileges and the necessary repositories enabled.

config="$HOME/.config"


# Install chaotic-aur repository
if ! grep -q "chaotic-aur" /etc/pacman.conf; then
  wget -q -O chaotic-AUR-installer.bash https://raw.githubusercontent.com/SharafatKarim/chaotic-AUR-installer/main/install.bash && sudo bash chaotic-AUR-installer.bash && rm chaotic-AUR-installer.bash
fi

sudo pacman -S hyprland hypridle hyprlock wlogout libnotify brightnessctl yay btop playerctl wofi rofi wezterm kitty polkit-gnome power-profiles-daemon noto-fonts-emoji ttf-fira-code ttf-font-awesome swww hyprpaper grim slurp blueman cmake meson cpio pkg-config git gcc curl wget

yay -S pyprland python-pywal16

for dir in hypr fastfetch rofi wofi wal waybar wlogout dunst wezterm swaync; do
  src_dir="$PWD/$dir"
  dest_dir="$config/$dir"
  if [ -d "$src_dir" ]; then
    mkdir -p "$dest_dir"
    cp -rf "$src_dir/"* "$dest_dir/"
  else
    echo "Warning: $src_dir not found, skipping."
  fi
done

mkdir -p "$HOME/Pictures/wallpapers"

# Change to the cloned dotfiles directory
cd "$HOME/hypr-dotfiles"

# Copy wallpapers from cloned repo to user's wallpapers folder
if [ -d "$PWD/wallpapers" ]; then
  cp -r "$PWD/wallpapers/"* "$HOME/Pictures/wallpapers/"
else
  echo "Warning: wallpapers directory not found in $PWD"
fi