#!/bin/bash

if ip link show wg0 2>&1 | grep -q "state UP"; then
    echo '{"text":"WG: 🔒","class":"connected","tooltip":"WireGuard Active"}'
else
    echo '{"text":"WG: 🔓","class":"disconnected","tooltip":"WireGuard Inactive"}'
fi
