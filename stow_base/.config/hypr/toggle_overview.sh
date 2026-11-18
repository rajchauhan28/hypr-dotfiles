#!/bin/bash
# Match the overview INSTANCE (`qs -p .../quickshell/overview`) only. The old
# pattern "quickshell.*overview" also matched any process that merely had a
# file from that directory on its command line -- e.g. an editor open on
# overview/WorkspaceCard.qml -- and Super+Tab killed it.
pattern="^(qs|quickshell) .*-p [^ ]*/quickshell/overview/?( |$)"
if pgrep -f "$pattern" >/dev/null; then
    pkill -f "$pattern"
else
    qs -p "$HOME/.config/quickshell/overview"
fi
