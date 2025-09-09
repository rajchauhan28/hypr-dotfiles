#!/bin/bash

cpu=$(grep -o "^[0-9]*" /proc/loadavg)
mem=$(free -m | awk '/Mem:/ { printf("%.0f"), $3/$2 * 100}')
temp=$(sensors | awk '/Package id 0:/ {gsub(/\+|°C/, "", $4); print int($4); exit}')

echo "{\"text\": \" ${cpu} |  ${mem}% |  ${temp}°C\"}"
