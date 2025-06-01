#!/bin/bash
# Install Hyprland and its dependencies on Arch Linux
# This script assumes you have sudo privileges and the necessary repositories enabled.
$config = ~/.config

sudo pacman -S hyprland hypridle hyprlock wlogout libnotify brightnessctl playerctl wofi rofi wezterm kitty polkit-gnome python-pywal16 power-profiles-daemon noto-fonts-emoji ttf-fira-code ttf-font-awesome swww hyprpaper grim slurp stead blueman 
hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors

cp -r hypr "$config/"
cp -r fastfetch "$config/"
cp -r rofi "$config/"
cp -r wofi "$config/"
cp -r wal "$config/"
cp -r waybar "$config/"
cp -r wlogout "$config/"
cp -r dunst "$config/"
cp -r wezterm "$config/"
cp -r swaync "$config/"
