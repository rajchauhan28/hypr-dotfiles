#!/bin/bash

DIR=$HOME/Pictures/wallpapers/
PICS=($(find ${DIR} -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \)))
RANDOMPICS=${PICS[ $RANDOM % ${#PICS[@]} ]}

# Function to change wallpaper with swaybg
change_swaybg(){
  pkill swww
  pkill swaybg
  swaybg -m fill -i ${RANDOMPICS}
  
  # Use pywal to update colors
  wal -i ${RANDOMPICS}

  # Reload Alacritty config to apply new colors using alacritty-msg
  alacritty-msg reload

  # Optionally, restart Waybar to reflect theme changes
  pkill waybar
  waybar &
}

# Function to change wallpaper with swww
change_swww(){
  pkill swaybg
  swww query || swww init
  swww img ${RANDOMPICS} --transition-fps 30 --transition-type any --transition-duration 2
  
  # Use pywal to update colors
  wal -i ${RANDOMPICS}

  # Reload Alacritty config to apply new colors using alacritty-msg
  alacritty-msg reload

  # Optionally, restart Waybar to reflect theme changes
  pkill waybar
  waybar &
}

# Function to change the current wallpaper based on whether swaybg is running
change_current(){
  if pidof swaybg >/dev/null; then
    change_swaybg
  else
    change_swww
  fi
}

# Function to toggle between swaybg and swww depending on the current state
switch(){
  if pidof swaybg >/dev/null; then
    change_swww
  else
    change_swaybg
  fi
}

# Main script logic based on the input argument
case "$1" in
	"swaybg")
		change_swaybg
		;;
	"swww")
		change_swww
		;;
  "s")
		switch
		;;
	*)
		change_current
		;;
esac
