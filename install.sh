#!/bin/bash

# Exit on error
set -e

# Define paths
CONFIG_FOLDER="."  # Using the current directory as the config folder
HYPR_CONFIG_DIR="$HOME/.config/hypr"   # Default config directory for Hyprland
WAYBAR_CONFIG_DIR="$HOME/.config/waybar"  # Default config directory for Waybar
ROFI_CONFIG_DIR="$HOME/.config/rofi"    # Default config directory for Rofi

# Check if running as root (for installation)
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root to install dependencies."
    exit 1
fi

# Step 1: Install Dependencies
echo "Installing required dependencies..."

# Update system and install packages
pacman -Syu --noconfirm   # Update system
pacman -S --noconfirm hyprland waybar rofi wayland-utils xorg-xwayland \
    xorg-server xorg-xinit swaybg swaylock xdg-desktop-portal-gtk \
    libinput alsa-utils pipewire pipewire-alsa pipewire-pulse pavucontrol \
    gst-plugin-pipewire xdg-utils feh libnotify brightnessctl bluez bluez-utils --needed

# Install any additional dependencies you might need for your specific setup
# e.g. fonts, themes, etc.
# pacman -S --noconfirm noto-fonts-emoji ttf-joypixels

# Step 2: Copy Configuration Files
echo "Copying configuration files..."

# Ensure directories exist
mkdir -p "$HYPR_CONFIG_DIR"
mkdir -p "$WAYBAR_CONFIG_DIR"
mkdir -p "$ROFI_CONFIG_DIR"

# Check if the config folder exists and contains the right subdirectories
if [ ! -d "$CONFIG_FOLDER/hypr" ]; then
    echo "Error: Hyprland config folder does not exist in $CONFIG_FOLDER."
    exit 1
fi

if [ ! -d "$CONFIG_FOLDER/waybar" ]; then
    echo "Error: Waybar config folder does not exist in $CONFIG_FOLDER."
    exit 1
fi

# Copy your configuration files to the respective directories
cp -r "$CONFIG_FOLDER/hypr"/* "$HYPR_CONFIG_DIR/"
cp -r "$CONFIG_FOLDER/waybar"/* "$WAYBAR_CONFIG_DIR/"


# Step 3: Set appropriate permissions (if needed)
echo "Setting proper file permissions..."
chmod -R 700 "$HYPR_CONFIG_DIR"
chmod -R 700 "$WAYBAR_CONFIG_DIR"
#chmod -R 700 "$ROFI_CONFIG_DIR"

# Step 4: Enable and start services (Optional)
echo "Starting services..."

# Enable and start pipewire (if needed)
systemctl --user enable pipewire --now
systemctl --user enable pipewire-pulse --now

# Enable Waybar, Hyprland, and Rofi (if you're using a display manager, modify accordingly)
#systemctl --user enable hyprland.service  # Uncomment if you have a systemd service for Hyprland
#ystemctl --user enable waybar.service  # Uncomment if you have a systemd service for Waybar
# systemctl --user enable rofi.service    # Uncomment if you have a systemd service for Rofi

# Step 5: Launch Hyprland (Optional)
echo "Launching Hyprland..."
# This is just an example; you may need a specific command or session to launch Hyprland
startx # If using X server or Wayland session via startx
