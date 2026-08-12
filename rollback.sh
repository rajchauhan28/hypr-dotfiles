#!/bin/bash
#
# ██████╗  ██████╗ ██╗     ██╗     ██████╗  █████╗  ██████╗██╗  ██╗
# ██╔══██╗██╔═══██╗██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║
# ██████╔╝██║   ██║██║     ██║     ██████╔╝███████║██║     ███████║
# ██╔══██╗██║   ██║██║     ██║     ██╔══██╗██╔══██║██║     ██╔══██║
# ██║  ██║╚██████╔╝███████╗███████╗██████╔╝██║  ██║╚██████╗██║  ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
#
# Rollback Script: Restores previous hypr-dotfiles setup from hypr-dotfiles-old

set -e

readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

OLD_BACKUP="$HOME/hypr-dotfiles-old"
CURRENT_REPO="$HOME/hypr-dotfiles"

echo -e "${C_CYAN}🔄 Starting Rollback to previous Hyprland Dotfiles backup...${C_RESET}"

if [ ! -d "$OLD_BACKUP" ]; then
    echo -e "${C_RED}❌ Error: Backup directory '$OLD_BACKUP' was not found. Cannot rollback.${C_RESET}"
    exit 1
fi

echo -e "${C_YELLOW}⚠️ Unstowing current dotfiles...${C_RESET}"
if [ -d "$CURRENT_REPO/stow_base" ]; then
    cd "$CURRENT_REPO/stow_base"
    stow -D -t "$HOME" . || true
    cd "$HOME"
fi

echo -e "${C_BLUE}📦 Restoring backup from hypr-dotfiles-old...${C_RESET}"
rm -rf "$CURRENT_REPO"
cp -r "$OLD_BACKUP" "$CURRENT_REPO"

echo -e "${C_BLUE}📂 Re-stowing restored configuration...${C_RESET}"
cd "$CURRENT_REPO/stow_base"
stow -t "$HOME" .
cd "$HOME"

echo -e "${C_GREEN}✅ Rollback completed successfully! Please restart Hyprland or reboot.${C_RESET}"
