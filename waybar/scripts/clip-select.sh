#!/bin/sh
cliphist list | wofi -n --dmenu | cliphist decode | wl-copy
