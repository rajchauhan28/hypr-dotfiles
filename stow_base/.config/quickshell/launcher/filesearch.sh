#!/bin/sh
# One source of file results for the launcher's `files` mode.
#
# Split into two stages on purpose, because their latencies differ by three
# orders of magnitude on this machine:
#
#   fast (plocate) ~5 ms    the system index, whole filesystem, but blind to
#                           anything created since the last updatedb run.
#   slow (fd)      ~1-3 s   a live walk of $HOME, which is where those
#                           too-new-to-be-indexed files actually are.
#
# The launcher runs these as separate processes and merges them as they land,
# so the indexed hits are on screen while the live walk is still going. Running
# them as one pipeline made every keystroke wait for the slow half.
#
# Usage: filesearch.sh fast|slow <query>
set -u

stage="${1:-}"
q="${2:-}"
[ -z "$q" ] && exit 0

case "$stage" in
    fast)
        plocate -i -l 300 -- "$q" 2>/dev/null
        ;;
    slow)
        # .gitignore is respected here (no --no-ignore-vcs): build output and
        # vendored trees are exactly what nobody is searching for, and skipping
        # them is most of the speed. The excludes cover the heavy directories
        # that no VCS ignore file covers.
        fd --hidden --type f --max-results 150 \
           --exclude .git --exclude node_modules --exclude .cache \
           --exclude .venv --exclude target --exclude __pycache__ \
           --base-directory "$HOME" -- "$q" 2>/dev/null |
            sed "s|^|$HOME/|"
        ;;
    *)
        exit 2
        ;;
esac
