import QtQuick
import QtQuick.Layouts
import Quickshell

// One entry in the dock's pinned list: icon, name, the app_id the dock matches
// running windows against, and the reorder/remove/icon controls.
Rectangle {
    id: entry

    property var app: ({})
    property int itemIndex: -1
    property bool isFirst: false
    property bool isLast: false
    property bool pickerOpen: false

    signal moveUp
    signal moveDown
    signal removed

    Layout.fillWidth: true
    implicitHeight: pickerOpen ? 240 : 46
    radius: Theme.radiusSmall
    color: rowMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
    border.color: pickerOpen ? Theme.accent : Theme.border
    border.width: 1
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !entry.pickerOpen
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            Layout.leftMargin: 10
            Layout.rightMargin: 8
            spacing: 10

            Item {
                implicitWidth: 26
                implicitHeight: 26

                Image {
                    id: icon
                    anchors.fill: parent
                    source: {
                        var direct = Quickshell.iconPath(entry.app.icon || entry.app["class"] || "", true);
                        if (direct !== "") return direct;
                        return Quickshell.iconPath(Config.getAvailableIcon(entry.app.icon, entry.app.name, entry.app["class"]), true);
                    }
                    sourceSize: Qt.size(52, 52)
                    smooth: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰣆"
                    font.pixelSize: 18
                    color: Theme.textFaint
                    visible: icon.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: entry.app.name || entry.app.exec || "?"
                    font.pixelSize: 12
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: (entry.app.icon ? "Icon: " + entry.app.icon + " • " : "") + (entry.app["class"] || "no class")
                    font.pixelSize: 9
                    font.family: "monospace"
                    color: entry.app["class"] ? Theme.textFaint : Theme.warn
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Repeater {
                model: [
                    { glyph: "󰏫", act: "icon", title: "Change icon" },
                    { glyph: "󰅃", act: "up", title: "Move up" },
                    { glyph: "󰅀", act: "down", title: "Move down" },
                    { glyph: "󰅖", act: "remove", title: "Unpin app" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool disabled:
                        (modelData.act === "up" && entry.isFirst)
                        || (modelData.act === "down" && entry.isLast)
                    readonly property bool destructive: modelData.act === "remove"
                    readonly property bool active: modelData.act === "icon" && entry.pickerOpen

                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 6
                    color: active ? Theme.accent : (btnMouse.containsMouse && !disabled ? Theme.cardHover : "transparent")
                    border.color: btnMouse.containsMouse && !disabled ? Theme.border : "transparent"
                    border.width: 1
                    opacity: disabled ? 0.25 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        font.pixelSize: 13
                        color: parent.active ? "#0a0a0f" : (btnMouse.containsMouse && parent.destructive ? Theme.danger : Theme.textSecondary)
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !parent.disabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.act === "icon")
                                entry.pickerOpen = !entry.pickerOpen;
                            else if (modelData.act === "up")
                                entry.moveUp();
                            else if (modelData.act === "down")
                                entry.moveDown();
                            else
                                entry.removed();
                        }
                    }
                }
            }
        }

        // Icon Chooser Panel (expanded when pickerOpen is true)
        ColumnLayout {
            visible: entry.pickerOpen
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.border
            }

            Text {
                text: "CHANGE APP ICON (Select from available apps or type custom icon name):"
                font.pixelSize: 10
                font.bold: true
                color: Theme.accent
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 6
                    color: Theme.cardAlt
                    border.color: iconSearch.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: "󰍉"
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }

                        TextInput {
                            id: iconSearch
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Filter available app icons or type custom icon name…"
                                font: iconSearch.font
                                color: Theme.textFaint
                                visible: iconSearch.text === ""
                            }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 70
                    implicitHeight: 28
                    radius: 6
                    color: applyCustomMouse.containsMouse ? Theme.accent : Theme.cardHover
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: 11
                        font.bold: true
                        color: applyCustomMouse.containsMouse ? "#0a0a0f" : Theme.textPrimary
                    }

                    MouseArea {
                        id: applyCustomMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var custom = iconSearch.text.trim();
                            if (custom !== "") {
                                var best = Config.getAvailableIcon(custom, entry.app.name, entry.app["class"]);
                                Config.changePinnedIcon(entry.itemIndex, best);
                                entry.pickerOpen = false;
                            }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 60
                    implicitHeight: 28
                    radius: 6
                    color: resetMouse.containsMouse ? Theme.cardHover : "transparent"
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        font.pixelSize: 11
                        color: Theme.textMuted
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var original = entry.app["class"] || entry.app.name || "";
                            Config.changePinnedIcon(entry.itemIndex, original);
                            entry.pickerOpen = false;
                        }
                    }
                }
            }

            // Grid of Available Icons from other apps
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 110
                radius: 6
                color: Theme.cardAlt
                border.color: Theme.border
                border.width: 1
                clip: true

                readonly property var filteredApps: {
                    var q = iconSearch.text.toLowerCase().trim();
                    var out = [];
                    for (var i = 0; i < Config.apps.length; i++) {
                        var a = Config.apps[i];
                        if (!a.icon) continue;
                        if (q !== "" && a.name.toLowerCase().indexOf(q) === -1 &&
                            a.icon.toLowerCase().indexOf(q) === -1 &&
                            a["class"].toLowerCase().indexOf(q) === -1)
                            continue;
                        out.push(a);
                    }
                    return out;
                }

                ListView {
                    id: iconList
                    anchors.fill: parent
                    anchors.margins: 4
                    orientation: ListView.Horizontal
                    model: parent.filteredApps
                    spacing: 6
                    clip: true

                    delegate: Rectangle {
                        required property var modelData

                        width: 72
                        height: 98
                        radius: 6
                        color: pickMouse.containsMouse ? Theme.cardHover : "transparent"
                        border.color: pickMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 36
                                implicitHeight: 36

                                Image {
                                    id: itemIconImg
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(modelData.icon, true)
                                    sourceSize: Qt.size(72, 72)
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰣆"
                                    font.pixelSize: 22
                                    color: Theme.textFaint
                                    visible: itemIconImg.status !== Image.Ready
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 10
                                color: Theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }
                        }

                        MouseArea {
                            id: pickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var chosen = modelData.icon;
                                var validated = Config.getAvailableIcon(chosen, modelData.name, modelData["class"]);
                                Config.changePinnedIcon(entry.itemIndex, validated);
                                entry.pickerOpen = false;
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: iconList.count === 0
                    text: "No available icons match search query"
                    font.pixelSize: 11
                    color: Theme.textFaint
                }
            }
        }
    }
}
