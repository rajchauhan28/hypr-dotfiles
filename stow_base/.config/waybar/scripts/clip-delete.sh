#!/bin/sh
cliphist list | wofi --dmenu | cliphist delete
