#!/usr/bin/env bash
# One-shot migration of elephant's clipboard history into cliphist.
#
# Reads the history out of the running elephant rather than parsing
# ~/.cache/elephant/clipboard.gob directly: gob is a Go-internal format with no
# stable external reader, whereas `elephant query` hands over the same data as
# JSON, images included. This means elephant must still be RUNNING when this is
# run -- do the migration before tearing the service down.
#
# cliphist orders by insertion, so entries are replayed oldest-first to come
# out in their original order.
set -uo pipefail

DRY_RUN=0
LIMIT=10000
EXCLUDE_REGEX=""

usage() {
    cat <<'USAGE'
Usage: migrate-elephant-clipboard.sh [options]

  --apply                 Actually write to cliphist. Without this the script
                          only reports what it would do (default: dry run).
  --limit N               Migrate at most N most-recent entries (default 10000).
  --exclude-regex REGEX   Skip text entries matching this ERE. Use it to keep
                          credentials out of the new store.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)          DRY_RUN=0; APPLIED=1; shift ;;
        --dry-run)        DRY_RUN=1; shift ;;
        --limit)          LIMIT="$2"; shift 2 ;;
        --exclude-regex)  EXCLUDE_REGEX="$2"; shift 2 ;;
        -h|--help)        usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 2 ;;
    esac
done
# Default to a dry run: this writes to the user's real clipboard history, so
# the destructive-looking direction has to be asked for explicitly.
DRY_RUN=${APPLIED:+0}; DRY_RUN=${DRY_RUN:-1}

command -v cliphist >/dev/null || { echo "cliphist is not installed" >&2; exit 1; }
command -v jq       >/dev/null || { echo "jq is not installed" >&2; exit 1; }
systemctl --user is-active --quiet elephant || {
    echo "elephant.service is not running -- start it before migrating" >&2
    exit 1
}

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

if ! timeout 30 elephant query --json "clipboard;;$LIMIT" > "$tmp" 2>/dev/null; then
    echo "elephant query failed" >&2
    exit 1
fi

total=$(wc -l < "$tmp")
echo "elephant reports $total entries"

migrated=0 skipped=0 images=0 missing=0

# tac: elephant emits newest-first, cliphist orders by insertion.
while IFS= read -r line; do
    [ -z "$line" ] && continue

    ptype=$(jq -r '.item.preview_type // "text"' <<<"$line" 2>/dev/null) || continue

    if [ "$ptype" = "file" ]; then
        img=$(jq -r '.item.preview // ""' <<<"$line")
        if [ -z "$img" ] || [ ! -f "$img" ]; then
            missing=$((missing + 1))
            continue
        fi
        if [ "$DRY_RUN" = 1 ]; then
            echo "  [image] $img"
        else
            cliphist store < "$img"
        fi
        images=$((images + 1))
        migrated=$((migrated + 1))
        continue
    fi

    text=$(jq -r '.item.text // ""' <<<"$line")
    [ -z "$text" ] && continue

    if [ -n "$EXCLUDE_REGEX" ] && printf '%s' "$text" | grep -qE "$EXCLUDE_REGEX"; then
        skipped=$((skipped + 1))
        echo "  [skip] ${text:0:40}..."
        continue
    fi

    if [ "$DRY_RUN" = 1 ]; then
        printf '  [text]  %.60s\n' "$text"
    else
        printf '%s' "$text" | cliphist store
    fi
    migrated=$((migrated + 1))
done < <(tac "$tmp")

echo
echo "migrated: $migrated  (of which images: $images)"
echo "skipped by --exclude-regex: $skipped"
echo "image files missing on disk: $missing"
[ "$DRY_RUN" = 1 ] && echo && echo "DRY RUN -- nothing written. Re-run with --apply to commit."
exit 0
