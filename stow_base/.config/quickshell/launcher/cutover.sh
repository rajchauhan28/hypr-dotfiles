#!/usr/bin/env bash
# Final step of the walker/elephant -> Quickshell launcher migration.
#
# Split out from the build because it needs cliphist, which needs root to
# install. Everything before this point is already live and reversible; this is
# the step that actually retires walker and elephant.
#
# Order matters: the history has to be copied out of elephant while elephant is
# still running, and clipboard capture has to be handed over before elephant
# stops, or copies made in the gap are lost.
set -uo pipefail

DRY=1
EXCLUDE_REGEX=""
for a in "$@"; do
    case "$a" in
        --apply) DRY=0 ;;
        --exclude-regex=*) EXCLUDE_REGEX="${a#*=}" ;;
        -h|--help)
            sed -n '2,14p' "$0"; exit 0 ;;
    esac
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
run() {
    if [ "$DRY" = 1 ]; then
        printf '   would run: %s\n' "$*"
    else
        printf '   %s\n' "$*"
        "$@"
    fi
}

# ---------------------------------------------------------------- preflight
say "Preflight"
fail=0
if ! command -v cliphist >/dev/null; then
    echo "   MISSING: cliphist   ->  sudo pacman -S cliphist"
    fail=1
else
    echo "   ok: cliphist $(cliphist version 2>/dev/null || echo present)"
fi
if ! qs ipc call launcher close >/dev/null 2>&1; then
    echo "   MISSING: the Quickshell launcher IPC is not answering."
    echo "           Is the shell running?  ~/.config/quickshell/reload.sh"
    fail=1
else
    echo "   ok: launcher IPC responding"
fi
if ! systemctl --user is-active --quiet elephant; then
    echo "   WARNING: elephant is not running -- clipboard history cannot be migrated."
    echo "            Start it first:  systemctl --user start elephant"
    fail=1
else
    echo "   ok: elephant running (history readable)"
fi
[ "$fail" = 1 ] && { echo; echo "Preflight failed. Nothing changed."; exit 1; }

# ------------------------------------------------------- 1. capture handover
# Start capturing BEFORE elephant stops so no copy falls through the gap.
say "1. Start cliphist capture"
run systemctl --user daemon-reload
run systemctl --user enable --now cliphist-text.service
run systemctl --user enable --now cliphist-image.service

# ------------------------------------------------------------ 2. migrate
say "2. Migrate clipboard history out of elephant"
mig=("$HOME/.config/quickshell/launcher/migrate-elephant-clipboard.sh")
[ -n "$EXCLUDE_REGEX" ] && mig+=(--exclude-regex "$EXCLUDE_REGEX")
if [ "$DRY" = 1 ]; then
    printf '   would run: %s --apply\n' "${mig[*]}"
    "${mig[@]}" 2>&1 | tail -6
else
    "${mig[@]}" --apply
fi

# ------------------------------------------------------- 3. flip Super+C
say "3. Point Super+C at the Quickshell clipboard panel"
if [ "$DRY" = 1 ]; then
    echo "   would rewrite the Super+C bind in ~/.config/hypr/hyprland.lua"
else
    python3 - <<'PY'
import pathlib
p = pathlib.Path.home() / ".config/hypr/hyprland.lua"
s = p.read_text()
s = s.replace(
    '-- Still walker: the Quickshell clipboard panel needs cliphist installed and\n'
    '-- the elephant history migrated first. launcher/cutover.sh flips this.\n'
    'hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("walker -m clipboard"))',
    'hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call launcher clipboard"))')
p.write_text(s)
print("   Super+C rebound")
PY
    hyprctl reload >/dev/null 2>&1
fi

# ------------------------------------------------- 4. retire walker/elephant
say "4. Stop and disable walker + elephant"
run systemctl --user disable --now walker.service
run systemctl --user disable --now elephant.service

say "5. Remove them from the Hyprland session startup"
if [ "$DRY" = 1 ]; then
    echo "   would drop 'walker.service elephant.service' from the exec-once line"
else
    python3 - <<'PY'
import pathlib, re
for name in ("hyprland.lua", "hyprland.conf"):
    p = pathlib.Path.home() / ".config/hypr" / name
    if not p.exists():
        continue
    s = p.read_text()
    s2 = re.sub(r' +walker\.service| +elephant\.service', '', s)
    if s2 != s:
        p.write_text(s2)
        print(f"   cleaned {name}")
PY
fi

echo
if [ "$DRY" = 1 ]; then
    cat <<'MSG'
DRY RUN -- nothing changed.

Re-run with --apply to commit. To keep a credential out of the new history:
  cutover.sh --apply --exclude-regex='^([A-Za-z0-9]{4} ){11}[A-Za-z0-9]{4}$'

Afterwards, once you are happy, the packages can go:
  sudo pacman -Rns walker $(pacman -Qq 2>/dev/null | grep '^elephant-' | tr '\n' ' ')
MSG
else
    cat <<'MSG'
Cutover complete.

Rollback if needed:
  systemctl --user enable --now walker.service elephant.service
  git -C ~/hypr-dotfiles diff              # review the config edits
MSG
fi
