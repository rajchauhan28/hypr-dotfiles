import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page

    spacing: Theme.gap

    Card {
        title: "PINNED SIDEBAR APPS"
        subtitle: "Order here is order in the left sidebar"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Config.sidebarPinned

                delegate: PinnedRow {
                    required property var modelData
                    required property int index

                    app: modelData
                    itemIndex: index
                    isFirst: index === 0
                    isLast: index === Config.sidebarPinned.length - 1

                    onMoveUp: Config.reorderSidebarPinned(index, -1)
                    onMoveDown: Config.reorderSidebarPinned(index, 1)
                    onRemoved: Config.removeSidebarPinned(index)
                }
            }

            Text {
                visible: Config.sidebarPinned.length === 0
                text: "Nothing pinned to sidebar."
                font.pixelSize: 11
                color: Theme.textFaint
                Layout.topMargin: 4
            }
        }
    }

    Card {
        title: "ADD APP TO SIDEBAR"
        subtitle: Config.apps.length + " desktop entries found"

        ColumnLayout {
            id: picker
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSmall
                color: Theme.cardAlt
                border.color: search.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰍉"
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        color: Theme.textPrimary
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search applications for sidebar…"
                            font: search.font
                            color: Theme.textFaint
                            visible: search.text === ""
                        }
                    }
                }
            }

            readonly property var matches: {
                var q = search.text.toLowerCase().trim();
                var out = [];
                var pinnedClasses = {};
                for (var j = 0; j < Config.sidebarPinned.length; j++)
                    pinnedClasses[Config.sidebarPinned[j]["class"]] = true;
                for (var i = 0; i < Config.apps.length; i++) {
                    var a = Config.apps[i];
                    if (pinnedClasses[a["class"]])
                        continue;
                    if (q !== "" && a.name.toLowerCase().indexOf(q) === -1
                            && a["class"].toLowerCase().indexOf(q) === -1)
                        continue;
                    out.push(a);
                }
                return out;
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 160
                radius: Theme.radiusSmall
                color: Theme.cardAlt
                border.color: Theme.border
                border.width: 1
                clip: true

                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: picker.matches
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData

                        width: appList.width
                        height: 34
                        radius: 7
                        color: appMouse.containsMouse ? Theme.cardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Image {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                source: Quickshell.iconPath(modelData.icon, true)
                                sourceSize: Qt.size(40, 40)
                                smooth: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 11
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: appMouse.containsMouse
                                text: "pin"
                                font.pixelSize: 10
                                color: Theme.accent
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.addSidebarPinned(modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: Config.apps.length === 0 ? "Reading desktop entries…" : "No matches"
                    font.pixelSize: 11
                    color: Theme.textFaint
                }
            }
        }
    }

    Card {
        title: "LEFT SIDEBAR — GEOMETRY & SIZE"
        subtitle: "The always-visible vertical sidebar on the left screen edge"
        section: "leftbar"
        keys: ["barWidth", "iconSlot", "barPadding", "radiusPanel", "radiusSmall"]

        SliderRow { section: "leftbar"; key: "barWidth"; label: "Sidebar width"; from: 40; to: 90; suffix: " px" }
        SliderRow { section: "leftbar"; key: "iconSlot"; label: "Button size"; from: 28; to: 60; suffix: " px" }
        SliderRow { section: "leftbar"; key: "barPadding"; label: "Bar padding"; from: 4; to: 24; suffix: " px" }
        SliderRow { section: "leftbar"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 32; suffix: " px" }
        SliderRow { section: "leftbar"; key: "radiusSmall"; label: "Button corner radius"; from: 0; to: 20; suffix: " px" }
    }
}
