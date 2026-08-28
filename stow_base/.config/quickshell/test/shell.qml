import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    Component.onCompleted: {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = [Quickshell.env("HOME") + "/.config/quickshell/overview/hyprctl-compat.sh", "workspace", "2"];
        p.running = true;
        p.exited.connect((code) => {
            console.log("Exited with", code);
            Qt.quit();
        });
    }
}
