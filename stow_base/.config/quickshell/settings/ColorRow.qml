import QtQuick
import QtQuick.Layouts

// One palette entry: a live swatch, an editable hex field, and a strip of
// presets. Colours are stored as the "#aarrggbb"/"#rrggbb" strings Qt parses
// directly, so the panels need no colour parsing of their own.
Item {
    id: row

    property string key: ""
    property string label: ""
    property var presets: []

    readonly property string value: Config.get("palette", row.key)
    readonly property bool modified: !Config.isDefault("palette", row.key)

    Layout.fillWidth: true
    implicitHeight: 62

    function apply(hex) {
        var v = hex.trim();
        if (v === "")
            return false;
        if (v[0] !== "#")
            v = "#" + v;
        // 6 or 8 hex digits (the panels use #aarrggbb for the translucent
        // panel background). Anything else would silently become black.
        if (!/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v))
            return false;
        Config.set("palette", row.key, v.toLowerCase());
        return true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: row.value
                border.color: Theme.borderStrong
                border.width: 1
            }

            Text {
                text: row.label
                font.pixelSize: 11
                color: Theme.textSecondary
            }

            Rectangle {
                visible: row.modified
                width: 5
                height: 5
                radius: 2.5
                color: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 96
                implicitHeight: 24
                radius: Theme.radiusSmall
                color: Theme.cardAlt
                border.color: hexField.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                TextInput {
                    id: hexField
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    font.family: "monospace"
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: "#0a0a0f"
                    selectByMouse: true

                    // Only follow the store while the field is idle, or typing
                    // would fight the binding on every keystroke. Written to
                    // rather than bound: the first assignment below would break
                    // a declarative `text: row.value` for good, and after that
                    // the field would sit on a stale hex while the swatch and
                    // the panels moved on (a preset click, or a card reset).
                    Component.onCompleted: text = row.value
                    onActiveFocusChanged: if (!activeFocus) text = row.value

                    Connections {
                        target: row
                        function onValueChanged() {
                            if (!hexField.activeFocus)
                                hexField.text = row.value;
                        }
                    }

                    onAccepted: {
                        if (!row.apply(text))
                            text = row.value;
                        focus = false;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: row.presets

                delegate: Rectangle {
                    required property string modelData

                    implicitWidth: 22
                    implicitHeight: 16
                    radius: 5
                    color: modelData
                    border.color: row.value === modelData ? Theme.textPrimary : Theme.border
                    border.width: row.value === modelData ? 2 : 1
                    scale: swatchMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.apply(modelData)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
