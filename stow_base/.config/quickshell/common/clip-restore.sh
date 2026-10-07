#!/bin/sh
# Put cliphist entry $1 back on the clipboard.
#
# Text is offered as text/plain explicitly. Left to sniff, wl-copy labels it by
# content -- a reply starting "Subject:" becomes message/rfc822 only -- and every
# app asking for text then finds nothing to paste. Images keep wl-copy's
# detection, which is what gives them their real image/* type.
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
cliphist decode "$1" > "$tmp" || exit 1
case $(file -b --mime-type "$tmp") in
    image/*) wl-copy < "$tmp" ;;
    *)       wl-copy --type 'text/plain;charset=utf-8' < "$tmp" ;;
esac
