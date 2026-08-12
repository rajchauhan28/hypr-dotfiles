import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Session controls. Every action here is disruptive and the panel opens on
// hover, so nothing fires on a single click: the first click arms a button and
// the second confirms, with the arm expiring on its own.
Item {
    id: power

    property string armed: ""

    readonly property var actions: [
        {
            key: "lock",
            glyph: "󰌾",
            label: "Lock",
            colour: Theme.textPrimary,
            // Matches the Super+L bind in hyprland.lua.
            cmd: ["hyprlock"],
            confirm: false
        },
        {
            key: "logout",
            glyph: "󰗽",
            label: "Log out",
            colour: Theme.warn,
            // NOT `hyprctl dispatch exit`: this Hyprland is configured in Lua,
            // so dispatch arguments are parsed as Lua. `eval` runs the same
            // call the Super+M bind uses.
            cmd: ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"],
            confirm: true
        },
        {
            key: "suspend",
            glyph: "󰤄",
            label: "Sleep",
            colour: Theme.textPrimary,
            cmd: ["systemctl", "suspend"],
            confirm: false
        },
        {
            key: "reboot",
            glyph: "󰜉",
            label: "Restart",
            colour: Theme.warn,
            cmd: ["systemctl", "reboot"],
            confirm: true
        },
        {
            key: "shutdown",
            glyph: "󰐥",
            label: "Shut down",
            colour: Theme.danger,
            cmd: ["systemctl", "poweroff"],
            confirm: true
        }
    ]

    function run(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', power);
        p.command = cmd;
        p.running = true;
    }

    function trigger(a) {
        if (!a.confirm) {
            power.armed = "";
            power.run(a.cmd);
            return;
        }
        if (power.armed === a.key) {
            power.armed = "";
            power.run(a.cmd);
        } else {
            power.armed = a.key;
            armTimer.restart();
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        repeat: false
        onTriggered: power.armed = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "POWER"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
                color: Theme.textMuted
            }
            Item { Layout.fillWidth: true }
            Text {
                // Doubles as the hover label and the confirm prompt, so the row
                // needs no tooltip layer of its own.
                text: {
                    for (var i = 0; i < power.actions.length; i++)
                        if (power.actions[i].key === power.armed)
                            return "Click again to " + power.actions[i].label.toLowerCase();
                    return btnRow.hoverLabel;
                }
                font.pixelSize: 9
                color: power.armed !== "" ? Theme.warn : Theme.textFaint
                elide: Text.ElideRight
                Layout.maximumWidth: 170
            }
        }

        RowLayout {
            id: btnRow
            Layout.fillWidth: true
            spacing: 8

            property string hoverLabel: ""

            Repeater {
                model: power.actions

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool isArmed: power.armed === modelData.key

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.radiusSmall
                    color: isArmed ? Qt.rgba(modelData.colour.r, modelData.colour.g,
                                             modelData.colour.b, 0.18)
                                   : (btnMouse.containsMouse ? Theme.cardHover : Theme.cardAlt)
                    border.color: isArmed ? modelData.colour : Theme.border
                    border.width: isArmed ? 2 : 1
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    scale: btnMouse.pressed ? 0.94 : (btnMouse.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.1 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        font.pixelSize: 16
                        color: btnMouse.containsMouse || parent.isArmed
                               ? modelData.colour : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: power.trigger(modelData)
                        onContainsMouseChanged: btnRow.hoverLabel = containsMouse ? modelData.label : ""
                    }
                }
            }
        }
    }
}
