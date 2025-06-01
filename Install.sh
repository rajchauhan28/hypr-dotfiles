#!/bin/bash
# Install Hyprland and its dependencies on Arch Linux
# This script assumes you have sudo privileges and the necessary repositories enabled.

config="$HOME/.config"

sudo pacman -S hyprland hypridle hyprlock wlogout libnotify brightnessctl playerctl wofi rofi wezterm kitty polkit-gnome power-profiles-daemon noto-fonts-emoji ttf-fira-code ttf-font-awesome swww hyprpaper grim slurp blueman

hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors

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