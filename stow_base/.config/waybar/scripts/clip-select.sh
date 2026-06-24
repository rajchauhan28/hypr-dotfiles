#!/bin/sh
cliphist list | walker --dmenu | cliphist decode | wl-copy
