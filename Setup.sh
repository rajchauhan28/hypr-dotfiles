#!/bin/bash

# Exit on error
set -e


git clone --depth=1 "https://github.com/rajchauhan28/hypr-dotfiles.git" "$HOME/hypr-dotfiles"

# Make the Install.sh executable
chmod +x "$CLONE_DIR/Install.sh"

# Run the installer
bash "$CLONE_DIR/Install.sh"
