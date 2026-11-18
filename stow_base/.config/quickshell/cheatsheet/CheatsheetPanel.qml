import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "../common" as Common

// Keybind cheatsheet. The rows come from keybinds.py, which reads the LIVE
// `hyprctl binds -j` (every bind in hyprland.lua carries a "Group: Label"
// description) plus the touchpad gestures, and is re-run on every open -- so
// the sheet can never drift from what is actually bound.
//
// Open with: Super+/ (global shortcut quickshell:cheatsheet) or
//            qs ipc call cheatsheet toggle
// Type to filter; Escape or a click outside closes it.
Scope {
    id: root

    property bool shown: false
    property var groups: []         // [{ group, items: [{ keys: [combo...], desc }] }]
    property string query: ""

    readonly property var visibleGroups: {
        var q = root.query.trim().toLowerCase();
        if (q === "")
            return root.groups;
        var out = [];
        for (var i = 0; i < root.groups.length; i++) {
            var g = root.groups[i];
            var groupHit = g.group.toLowerCase().indexOf(q) >= 0;
            var items = [];
            for (var j = 0; j < g.items.length; j++) {
                var it = g.items[j];
                if (groupHit || it.desc.toLowerCase().indexOf(q) >= 0
                        || it.keys.join(" ").toLowerCase().indexOf(q) >= 0)
                    items.push(it);
            }
            if (items.length > 0)
                out.push({ group: g.group, items: items });
        }
        return out;
    }

    function open() {
        root.query = "";
        loadProc.running = true;
        root.shown = true;
    }
    function close() { root.shown = false; }
    function toggle() { if (root.shown) root.close(); else root.open(); }

    Process {
        id: loadProc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/quickshell/cheatsheet/keybinds.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.groups = JSON.parse(text) || [];
                } catch (e) {
                    root.groups = [];
                }
            }
        }
    }

    // Keybinds arrive as Hyprland global shortcuts (hl.dsp.global("quickshell:<name>")
    // in hyprland.lua), handled in this process: no `qs ipc` process per
    // keypress. The IpcHandler below stays for scripts and the CLI.
    GlobalShortcut {
        name: "cheatsheet"
        description: "Keybind cheatsheet"
        onPressed: { root.toggle(); }
    }

    IpcHandler {
        target: "cheatsheet"
        function open(): void   { root.open(); }
        function close(): void  { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        visible: root.shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-cheatsheet"

        // Dimmed backdrop; a click on it closes the sheet.
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Rectangle {
            id: card

            readonly property int pad: 22
            readonly property int columns: width >= 1000 ? 3 : (width >= 640 ? 2 : 1)
            readonly property int gap: 14
            readonly property real colWidth: (body.width - (columns - 1) * gap) / columns

            anchors.centerIn: parent
            width: Math.min(Theme.maxWidth, parent.width - 80)
            height: Math.min(Theme.maxHeight, parent.height - 80)
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.panelBorder

            // Swallow clicks on the card so they do not reach the backdrop.
            MouseArea { anchors.fill: parent }

            Common.GlassRim {
                anchors.fill: parent
                radius: parent.radius
                visible: Theme.glass
            }

            Connections {
                target: root
                function onShownChanged() {
                    if (root.shown) {
                        search.text = "";
                        flick.contentY = 0;
                        search.forceActiveFocus();
                    }
                }
            }

            // Header: title, filter field, hint.
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: card.pad
                height: 36

                Text {
                    id: title
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keybinds"
                    color: Theme.textPrimary
                    font.pixelSize: 20
                    font.bold: true
                }

                Rectangle {
                    id: field
                    anchors.left: title.right
                    anchors.leftMargin: 18
                    anchors.right: hint.left
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    radius: 10
                    color: Theme.card
                    border.width: 1
                    border.color: search.activeFocus ? Theme.accent : Theme.border

                    TextInput {
                        id: search
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        clip: true
                        focus: true
                        onTextChanged: root.query = text

                        Keys.onEscapePressed: root.close()
                        Keys.onDownPressed: flick.contentY = Math.min(flick.contentY + 60,
                                                Math.max(0, flick.contentHeight - flick.height))
                        Keys.onUpPressed: flick.contentY = Math.max(0, flick.contentY - 60)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "filter by key or action…"
                            color: Theme.textFaint
                            font.pixelSize: 13
                        }
                    }
                }

                Text {
                    id: hint
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Esc to close"
                    color: Theme.textMuted
                    font.pixelSize: 11
                }
            }

            Rectangle {
                id: rule
                anchors.top: header.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.divider
            }

            Flickable {
                id: flick
                anchors.top: rule.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: card.pad
                anchors.topMargin: 16
                clip: true
                contentWidth: width
                contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // Columns are filled shortest-first (masonry), so a long group
                // never leaves a tall hole beside a short one.
                Row {
                    id: body
                    width: flick.width
                    spacing: card.gap

                    readonly property var layout: {
                        var n = card.columns;
                        var buckets = [], heights = [];
                        for (var c = 0; c < n; c++) { buckets.push([]); heights.push(0); }
                        for (var i = 0; i < root.visibleGroups.length; i++) {
                            var g = root.visibleGroups[i];
                            var best = 0;
                            for (c = 1; c < n; c++)
                                if (heights[c] < heights[best])
                                    best = c;
                            buckets[best].push(g);
                            heights[best] += 2 + g.items.length; // header ~ two rows
                        }
                        return buckets;
                    }

                    Repeater {
                        id: cols
                        model: body.layout.length

                        Column {
                            required property int index
                            width: card.colWidth
                            spacing: card.gap

                            Repeater {
                                model: body.layout[index] || []

                                Rectangle {
                                    id: groupCard
                                    required property var modelData
                                    width: parent.width
                                    implicitHeight: groupCol.implicitHeight + 24
                                    height: implicitHeight
                                    radius: 12
                                    color: Theme.cardAlt
                                    border.width: 1
                                    border.color: Theme.border

                                    Column {
                                        id: groupCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 6

                                        Text {
                                            text: groupCard.modelData.group.toUpperCase()
                                            color: Theme.textMuted
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.letterSpacing: 1.2
                                            bottomPadding: 2
                                        }

                                        Repeater {
                                            model: groupCard.modelData.items

                                            Item {
                                                id: bindRow
                                                required property var modelData
                                                width: groupCol.width
                                                height: Math.max(keyChip.height, descText.implicitHeight)

                                                // One chip per combo; alternatives stack.
                                                Column {
                                                    id: keyChip
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.min(implicitWidth, parent.width * 0.6)
                                                    spacing: 4

                                                    Repeater {
                                                        model: bindRow.modelData.keys

                                                        Rectangle {
                                                            required property var modelData
                                                            width: Math.min(chipText.implicitWidth + 14, bindRow.width * 0.6)
                                                            height: 24
                                                            radius: 6
                                                            color: Theme.card
                                                            border.width: 1
                                                            border.color: Theme.border

                                                            // Default font, not monospace: the
                                                            // monospace face here has no arrow
                                                            // glyphs, so Super+← rendered as a dash.
                                                            Text {
                                                                id: chipText
                                                                anchors.centerIn: parent
                                                                width: parent.width - 14
                                                                horizontalAlignment: Text.AlignHCenter
                                                                text: modelData
                                                                color: Theme.textPrimary
                                                                font.pixelSize: 12
                                                                font.weight: Font.Medium
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }
                                                }

                                                Text {
                                                    id: descText
                                                    anchors.left: keyChip.right
                                                    anchors.leftMargin: 10
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: bindRow.modelData.desc
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 13
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40
                    visible: root.visibleGroups.length === 0
                    text: root.groups.length === 0 ? "Reading binds…" : "No bind matches \"" + root.query + "\""
                    color: Theme.textMuted
                    font.pixelSize: 13
                }
            }
        }
    }
}
