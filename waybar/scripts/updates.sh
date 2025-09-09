#!/usr/bin/env bash

count=$(checkupdates 2>/dev/null | wc -l)

if [ "$count" -gt 0 ]; then
    echo "{\"text\": \" $count\", \"tooltip\": \"$count updates available\", \"class\": \"updates-available\"}"
else
    echo "{\"text\": \" 0\", \"tooltip\": \"System up-to-date\", \"class\": \"updates-none\"}"
fi

