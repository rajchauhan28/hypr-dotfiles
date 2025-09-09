#!/bin/bash

$a = 0
if $a==0; then
    pkill waybar
    $a=1
else

    waybar &
fi
