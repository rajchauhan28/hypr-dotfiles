import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common" as Common

// Compact popover with the most recent cliphist entries -- the "paste the
// thing from a minute ago" surface. Full search stays in the launcher (Super+C).
//
// Open with: qs ipc call clipboard toggle   (Super+Shift+V)
Scope {
    id: root

    property bool shown: false
    property var entries: []        // [{ id, preview }]

    function open() {
        listProc.running = true;
        root.shown = true;
    }
    function close() { root.shown = false; }
    function toggle() { if (root.shown) root.close(); else root.open(); }

    // cliphist lists newest-first as "<id>\t<preview>", preview already
    // truncated to ~100 chars by cliphist itself.
    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list | head -n " + Theme.rowCount]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (text || "").split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab > 0)
                        out.push({ id: lines[i].substring(0, tab), preview: lines[i].substring(tab + 1) });
                }
                root.entries = out;
            }
        }
    }

    function paste(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]);
        root.close();
    }

    // cliphist delete reads the original "<id>\t<preview>" line on stdin.
    function remove(id) {
        deleteProc.command = ["sh", "-c", "cliphist list | awk -F'\\t' -v id=\"$1\" '$1==id' | cliphist delete", "sh", id];
        deleteProc.running = true;
    }

    Process {
        id: deleteProc
        onExited: listProc.running = true
    }

    IpcHandler {
        target: "clipboard"
        function open(): void   { root.open(); }
        function close(): void  { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    PanelWindow {
        id: win

        // Full-screen and transparent while open, so a click anywhere outside
        // the card lands on the catcher below and closes the popover.
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        visible: root.shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-clipboard"

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            readonly property int headerH: 37   // title row 24 + 2x6 spacing + 1px rule

            x: parent.width - width - 20
            y: parent.height - height - 70
            width: Theme.panelWidth
            height: Math.min(Theme.panelHeight, 20 + headerH + Math.max(list.contentHeight, 40))
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder

            // Swallow clicks on the card's own background so they do not fall
            // through to the close catcher.
            MouseArea { anchors.fill: parent }

            Common.GlassRim {
                anchors.fill: parent
                radius: parent.radius
                visible: Theme.glass
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.close()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: {
                    if (list.currentIndex >= 0 && list.currentIndex < root.entries.length)
                        root.paste(root.entries[list.currentIndex].id);
                }
            }

            Connections {
                target: root
                function onShownChanged() {
                    if (root.shown) {
                        list.currentIndex = 0;
                        keys.forceActiveFocus();
                    }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clipboard"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑↓ Enter · Esc"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.divider }

                ListView {
                    id: list
                    width: parent.width
                    height: card.height - 20 - card.headerH
                    clip: true
                    model: root.entries
                    spacing: 2
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool active: ListView.isCurrentItem || rowMouse.containsMouse

                        width: ListView.view.width
                        height: Theme.rowHeight
                        radius: 8
                        color: row.active ? Theme.cardHover : Theme.card

                        Text {
                            anchors.left: parent.left
                            anchors.right: del.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.preview
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.paste(row.modelData.id)
                        }

                        // Declared after rowMouse so it sits on top and takes
                        // its own clicks.
                        Rectangle {
                            id: del
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            radius: 6
                            color: delMouse.containsMouse ? Theme.card : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.textSecondary
                                font.pixelSize: 16
                            }
                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.remove(row.modelData.id)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.entries.length === 0
                        text: "Clipboard history is empty"
                        color: Theme.textSecondary
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
