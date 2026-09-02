#!/usr/bin/env bash
# Resolve clipboard entries to something paintable, in one batch.
#
# Called once when the clipboard panel opens rather than once per row: each
# entry costs a cliphist decode (a DB read plus a file write) and spawning one
# process per visible delegate made scrolling stutter.
#
# stdin:  one entry per line, TAB separated:  <id> <fmt> <text>
#           fmt  = png/gif/jpeg/... for cliphist's binary entries, or "-" for a
#                  text entry. It must be "-" and never empty: tab counts as
#                  IFS whitespace, so `read` collapses consecutive tabs and an
#                  empty middle field silently shifts every later field left.
#           text = the entry's text, used to spot file paths and file:// URIs
# stdout: one line per resolvable entry:      <id> <kind> <payload>
#           image    payload = image file to display
#           animated payload = GIF to play (QML AnimatedImage)
#           video    payload = generated thumbnail
#           icon     payload = freedesktop icon name for the file type
#         Entries that resolve to nothing are simply omitted.
set -uo pipefail

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/launcher/clip"
mkdir -p "$CACHE" || exit 1

# Keep the cache from growing without bound. Cheap, and runs while the user is
# still reading the panel.
find "$CACHE" -type f -mtime +7 -delete 2>/dev/null &

# Map a mime type to the icon a file manager would show. The freedesktop
# convention is the mime type with '/' replaced by '-'; the generic fallback
# ("image-x-generic" for image/whatever) is what icon themes actually ship for
# the long tail, so emit both and let the UI take the first that resolves.
icon_for_mime() {
    local mime="$1"
    printf '%s,%s,%s' \
        "${mime//\//-}" \
        "${mime%%/*}-x-generic" \
        "text-x-generic"
}

while IFS=$'\t' read -r id fmt text; do
    [ -z "${id:-}" ] && continue

    # ---- cliphist binary entries -----------------------------------------
    if [ -n "${fmt:-}" ] && [ "$fmt" != "-" ]; then
        case "$fmt" in
            gif)                    kind=animated; ext=gif ;;
            png|jpeg|jpg|webp|bmp)  kind=image;    ext="$fmt" ;;
            *)                      kind=image;    ext="$fmt" ;;
        esac

        out="$CACHE/$id.$ext"
        if [ ! -s "$out" ]; then
            cliphist decode "$id" > "$out" 2>/dev/null </dev/null || { rm -f "$out"; continue; }
        fi
        [ -s "$out" ] && printf '%s\t%s\t%s\n' "$id" "$kind" "$out"
        continue
    fi

    # ---- text entries that name a file ------------------------------------
    # `cliphist list` TRUNCATES its preview (~100 chars, then an ellipsis), so
    # any path longer than that arrives cut in half and would fail the file
    # test below. Only the decoded entry has the real content. Decode just the
    # entries that could plausibly be a file reference -- doing it for every
    # text entry would be 60 pointless DB reads per panel open.
    case "$text" in
        /*|"~/"*|file://*)
            full=$(cliphist decode "$id" 2>/dev/null </dev/null | head -n 1 | head -c 4096)
            [ -n "$full" ] && text="$full"
            ;;
    esac

    path="$text"
    case "$path" in
        file://*) path=$(printf '%s' "${path#file://}" | sed 's/%20/ /g') ;;
    esac
    # Only a bare path is a file reference. A command line that merely mentions
    # one is still a command, and previewing it would be wrong.
    case "$path" in
        /*) ;;
        "~/"*) path="$HOME/${path#\~/}" ;;
        *) continue ;;
    esac
    [ -f "$path" ] || continue

    mime=$(xdg-mime query filetype "$path" 2>/dev/null)
    [ -z "$mime" ] && mime=$(file -b --mime-type "$path" 2>/dev/null)
    [ -z "$mime" ] && continue

    case "$mime" in
        image/gif)
            printf '%s\tanimated\t%s\n' "$id" "$path"
            ;;
        image/*)
            printf '%s\timage\t%s\n' "$id" "$path"
            ;;
        video/*)
            # Key the thumbnail on path+mtime so editing a file re-thumbnails
            # it instead of serving a stale frame.
            key=$(printf '%s|%s' "$path" "$(stat -c %Y "$path" 2>/dev/null)" | md5sum | cut -d' ' -f1)
            thumb="$CACHE/vid-$key.png"
            if [ ! -s "$thumb" ]; then
                ffmpegthumbnailer -i "$path" -o "$thumb" -s 256 -q 8 >/dev/null 2>&1 </dev/null || true
            fi
            if [ -s "$thumb" ]; then
                printf '%s\tvideo\t%s\n' "$id" "$thumb"
            else
                printf '%s\ticon\t%s\n' "$id" "$(icon_for_mime "$mime")"
            fi
            ;;
        *)
            printf '%s\ticon\t%s\n' "$id" "$(icon_for_mime "$mime")"
            ;;
    esac
done

wait 2>/dev/null || true
