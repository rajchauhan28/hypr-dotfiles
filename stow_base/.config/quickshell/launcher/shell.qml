// Standalone entry point, matching the other module directories: lets the
// launcher be run and iterated on its own with
//     qs -p ~/.config/quickshell/launcher
// without reloading the whole consolidated shell. Production loads
// LauncherPanel.qml from ../shell.qml instead.
import Quickshell

ShellRoot {
    LauncherPanel {}
}
