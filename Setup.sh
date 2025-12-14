#!/bin/bash
git clone --depth=1 "https://github.com/rajchauhan28/hypr-dotfiles.git" "$HOME/hypr-dotfiles"

chmod +x "$HOME/hypr-dotfiles/Install.sh"
bash "$HOME/hypr-dotfiles/Install.sh"