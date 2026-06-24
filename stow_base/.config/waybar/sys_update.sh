#!/usr/bin/env bash

# ASCII art for start (wrapped in single quotes, with escaped characters as needed)
START_ART=$(cat <<'EOF'

  ░██████                            ░██                                  ░██     ░██                   ░██               ░██                  ░██ 
 ░██   ░██                           ░██                                  ░██     ░██                   ░██               ░██                  ░██ 
░██         ░██    ░██  ░███████  ░████████  ░███████  ░█████████████     ░██     ░██ ░████████   ░████████  ░██████   ░████████  ░███████     ░██ 
 ░████████  ░██    ░██ ░██           ░██    ░██    ░██ ░██   ░██   ░██    ░██     ░██ ░██    ░██ ░██    ░██       ░██     ░██    ░██    ░██    ░██ 
        ░██ ░██    ░██  ░███████     ░██    ░█████████ ░██   ░██   ░██    ░██     ░██ ░██    ░██ ░██    ░██  ░███████     ░██    ░█████████    ░██ 
 ░██   ░██  ░██   ░███        ░██    ░██    ░██        ░██   ░██   ░██     ░██   ░██  ░███   ░██ ░██   ░███ ░██   ░██     ░██    ░██               
  ░██████    ░█████░██  ░███████      ░████  ░███████  ░██   ░██   ░██      ░██████   ░██░█████   ░█████░██  ░█████░██     ░████  ░███████     ░██ 
                   ░██                                                                ░██                                                          
             ░███████                                                                 ░██                                                          
                                                                                                                                                   EOF
)

# ASCII exit message
EXIT_ART=$(cat <<'EOF'


 $$$$$$\    $$                                $$$$$$$\            $$ |$$  |--\
$$  __$$\   $$ |                              $$  __$$\           $$ |$$  \__|                          $$ |$$ |
$$ /  \__|$$$$$$\    $$$$$$\  $$\   $$\       $$ |  $$ | $$$$$$\  $$ |$$ |$$\ $$$$$$$\   $$$$$$\        $$ |$$ |
\$$$$$$\  \_$$  _|   \____$$\ $$ |  $$ |      $$$$$$$  |$$  __$$\ $$ |$$ |$$ |$$  __$$\ $$  __$$\       $$ |$$ |
 \____$$\   $$ |     $$$$$$$ |$$ |  $$ |      $$  __$$< $$ /  $$ |$$ |$$ |$$ |$$ |  $$ |$$ /  $$ |      \__|\__|
$$\   $$ |  $$ |$$\ $$  __$$ |$$ |  $$ |      $$ |  $$ |$$ |  $$ |$$ |$$ |$$ |$$ |  $$ |$$ |  $$ |              
\$$$$$$  |  \$$$$  |\$$$$$$$ |\$$$$$$$ |      $$ |  $$ |\$$$$$$  |$$ |$$ |$$ |$$ |  $$ |\$$$$$$$ |      $$\ $$\ 
 \______/    \____/  \_______| \____$$ |      \__|  \__| \______/ \__|\__|\__|\__|  \__| \____$$ |      \__|\__|
                              $$\   $$ |                                                $$\   $$ |              
                              \$$$$$$  |                                                \$$$$$$  |              
                               \______/                                                  \______/               

Press Enter[Return] to exit!!                           
EOF
)

if [ "$1" = "update" ]; then
    # Clear screen, show intro art
    clear
    echo "$START_ART"

    # Step 1: Rate mirrors
    echo -e "\n> Rating mirrors (this may take a moment)..."
    if ! rate-mirrors --save /tmp/mirrors.json arch; then
      echo "⚠️  Failed to rate mirrors. Continuing anyway..."
    fi

    # Step 2: Update system
    echo -e "\n> Starting full system upgrade with pacman..."
    sleep 1
    sudo pacman -Syyu

    # Step 3: Show goodbye art
    echo "$EXIT_ART"
    read -p ""
    exit 0
else
    updates=$(checkupdates 2>/dev/null | wc -l)
    if [ "$updates" -gt 0 ]; then
        echo " $updates"
        echo "$updates updates available"
    else
        echo "✔"
        echo "System is up to date"
    fi
fi
