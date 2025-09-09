#!/usr/bin/env bash
# check_updates.sh
# Uses pacman/paru/yay checkupdates utility. Adjust to your helper.
avail=0
if command -v checkupdates >/dev/null 2>&1; then
  avail=$(checkupdates 2>/dev/null | wc -l)
elif command -v paru >/dev/null 2>&1; then
  avail=$(paru -Qu | wc -l)
fi

if [[ "$avail" -gt 0 ]]; then
  echo "{\"icon\":\"\",\"text\":\"$avail updates\",\"tooltip\":\"$avail packages need update\"}"
else
  echo "{\"icon\":\"\",\"text\":\"up-to-date\",\"tooltip\":\"No updates\"}"
fi

