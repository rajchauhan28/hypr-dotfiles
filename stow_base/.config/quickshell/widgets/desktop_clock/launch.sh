#!/bin/bash
# OBSOLETE as of the shell consolidation.
#
# The desktop clock is no longer its own `qs` process — it is one component of
# the consolidated shell at ~/.config/quickshell/shell.qml (DesktopClockPanel).
# There is no separate instance to toggle, so this script has nothing to kill.
#
# To reload the clock, reload the whole shell:  ~/.config/quickshell/reload.sh
echo "desktop_clock is part of the consolidated shell; use ~/.config/quickshell/reload.sh" >&2
exit 1
