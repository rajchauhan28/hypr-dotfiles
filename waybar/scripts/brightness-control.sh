#!/usr/bin/env bash

# Print usage error message
print_error() {
  cat <<"EOF"
Usage: ./brightnesscontrol.sh -o <action>
Valid actions are:
    i -- increase brightness [+2%]
    d -- decrease brightness [-2%]
EOF
}

# Send brightness notification
send_notification() {
  brightness=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)")
  notify-send -a "state" -r 91190 -i "gpm-brightness-lcd" -h int:value:"$brightness" "Brightness: ${brightness}%" -u low
}

# Get brightness and device info
get_brightness_info() {
  brightness=$(brightnessctl info | grep -oP "(?<=\()\d+(?=%)")
  device=$(brightnessctl -m | awk -F',' '{print $1}' | sed 's/_/ /g; s/\<./\U&/g')
  current_brightness=$(brightnessctl -m | awk -F',' '{print $3}')
  max_brightness=$(brightnessctl -m | awk -F',' '{print $5}')
}

# Get brightness icon based on level
get_icon() {
  if ((brightness <= 5)); then
    icon=""
  elif ((brightness <= 15)); then
    icon=""
  elif ((brightness <= 30)); then
    icon=""
  elif ((brightness <= 45)); then
    icon=""
  elif ((brightness <= 55)); then
    icon=""
  elif ((brightness <= 65)); then
    icon=""
  elif ((brightness <= 80)); then
    icon=""
  elif ((brightness <= 95)); then
    icon=""
  else
    icon=""
  fi
}

# Handle CLI arguments
while getopts o: opt; do
  case "${opt}" in
    o)
      case $OPTARG in
        i)
          brightnessctl set 2%+
          send_notification
          ;;
        d)
          brightnessctl set 2%-
          send_notification
          ;;
        *)
          print_error
          exit 1
          ;;
      esac
      exit 0
      ;;
    *)
      print_error
      exit 1
      ;;
  esac
done

# No arguments? Just print status JSON for Waybar
get_brightness_info
get_icon

module="${icon} ${brightness}%"
tooltip="Device Name: ${device}"
tooltip+="\nBrightness: ${current_brightness} / ${max_brightness}"

# Output JSON for Waybar
echo "{\"text\": \"${module}\", \"tooltip\": \"${tooltip}\"}"
