#!/usr/bin/env bash
#
# ██████╗  ██████╗ ██╗     ██╗     ██████╗  █████╗  ██████╗██╗  ██╗
# ██╔══██╗██╔═══██╗██║     ██║     ██╔══██╗██╔══██╗██╔════╝██║  ██║
# ██████╔╝██║   ██║██║     ██║     ██████╔╝███████║██║     ███████║
# ██╔══██╗██║   ██║██║     ██║     ██╔══██╗██╔══██║██║     ██╔══██║
# ██║  ██║╚██████╔╝███████╗███████╗██████╔╝██║  ██║╚██████╗██║  ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
#
# Undo an install: unstow this repository's dotfiles and put back whatever
# Install.sh moved out of the way.
#
# This used to restore from "$HOME/hypr-dotfiles-old" and `rm -rf` the live
# repository. Install.sh has never created that directory -- it backs up to
# $HOME/.dotfiles_backup_<timestamp> -- so the rollback could only ever abort,
# and on the one machine where a stale hypr-dotfiles-old did exist it would
# have deleted the repository along with any uncommitted work. It now restores
# from the real backups and never touches the repository at all.

set -Eeuo pipefail

readonly C_RESET='\033[0m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'

readonly CURRENT_REPO="${HOME}/hypr-dotfiles"

msg() { echo -e "${1}${2}${C_RESET}"; }

msg "$C_CYAN" "🔄 Rolling back the Hyprland dotfiles install..."

# Newest backup first; `ls -d` on a glob that matches nothing would print an
# error, so check for a match before using it.
backup=""
for candidate in "$HOME"/.dotfiles_backup_*; do
    [ -d "$candidate" ] || continue
    backup="$candidate"
done

if [ -z "$backup" ]; then
    msg "$C_RED" "❌ No \$HOME/.dotfiles_backup_* directory found; nothing to restore."
    msg "$C_BLUE" "   Install.sh creates one each run. If you have never run it, there is"
    msg "$C_BLUE" "   nothing to roll back to."
    exit 1
fi

msg "$C_BLUE" "  -> Restoring from $backup"

if [ -d "$CURRENT_REPO/stow_base" ]; then
    msg "$C_YELLOW" "⚠️  Unstowing current dotfiles..."
    ( cd "$CURRENT_REPO/stow_base" && stow -D -t "$HOME" . ) || true
fi

# Copy the backup tree back over $HOME. Dotglob so .config and friends are
# included; the repository itself is never touched.
msg "$C_BLUE" "📦 Restoring backed-up configuration..."
shopt -s dotglob nullglob
for entry in "$backup"/*; do
    target="$HOME/$(basename "$entry")"
    if [ -e "$target" ] || [ -L "$target" ]; then
        msg "$C_YELLOW" "  -> Replacing $(basename "$entry")"
        rm -rf "$target"
    fi
    cp -a "$entry" "$target"
done
shopt -u dotglob nullglob

# Generated per-machine files are meaningless once the shell is gone.
rm -f "$HOME/.config/hypr/hardware.conf" "$HOME/.config/hypr/hardware.lua"

msg "$C_GREEN" "✅ Rollback complete. Restart Hyprland or reboot."
msg "$C_BLUE"  "   The repository at $CURRENT_REPO was left untouched; delete it yourself"
msg "$C_BLUE"  "   if you no longer want it."
