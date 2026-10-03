#!/usr/bin/env bash
# Build and install the hyprglass plugin for the RUNNING Hyprland version.
#
# Re-run this after every Hyprland update: a plugin is compiled against one
# Hyprland's headers and the compositor refuses (or crashes on) anything else.
# hyprglass keeps one branch per Hyprland minor ("hyprland-0.56"), whose
# release is pinned to that version's commit.
#
# Installs to ~/.local/lib/hyprland/hyprglass.so, which glass.lua loads. It
# also clears the crash sentinel, so the next config load tries the new build.
set -euo pipefail

ver=$(hyprctl -j version | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag"].lstrip("v"))')
minor=${ver%.*}
hdr=$(pkg-config --modversion hyprland)
if [ "$hdr" != "$ver" ]; then
    echo "Hyprland headers are $hdr but the running compositor is $ver." >&2
    echo "Update the hyprland package (headers) first, or log out and back in." >&2
    exit 1
fi

src=${XDG_CACHE_HOME:-$HOME/.cache}/hyprglass-src
if [ -d "$src/.git" ]; then
    git -C "$src" fetch --depth 1 origin "hyprland-$minor"
    git -C "$src" checkout -q FETCH_HEAD
else
    git clone --depth 1 --branch "hyprland-$minor" https://github.com/hyprnux/hyprglass "$src"
fi

make -C "$src" clean >/dev/null
nice make -C "$src" -j"$(nproc)"
install -Dm755 "$src/hyprglass.so" "$HOME/.local/lib/hyprland/hyprglass.so"
rm -f "$HOME/.cache/hyprglass.loading"
echo "hyprglass $(git -C "$src" describe --tags --always) installed for Hyprland $ver."
echo "It loads on the next Hyprland start (or: hyprctl reload)."
