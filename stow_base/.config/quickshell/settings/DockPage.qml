import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page

    spacing: Theme.gap

    // The list mutations live in Config: it owns pinned.json, writes it
    // atomically, and the dock's FileView picks the result up live.

    Card {
        title: "PINNED APPS"
        subtitle: "Order here is order in the dock"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Config.pinned

                delegate: PinnedRow {
                    required property var modelData
                    required property int index

                    app: modelData
                    isFirst: index === 0
                    isLast: index === Config.pinned.length - 1

                    onMoveUp: Config.reorderPinned(index, -1)
                    onMoveDown: Config.reorderPinned(index, 1)
                    onRemoved: Config.removePinned(index)
                }
            }

            Text {
                visible: Config.pinned.length === 0
                text: "Nothing pinned. The dock will still show running apps."
                font.pixelSize: 11
                color: Theme.textFaint
                Layout.topMargin: 4
            }
        }
    }

    Card {
        title: "ADD AN APP"
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
                        selectionColor: Theme.accent
                        selectedTextColor: "#0a0a0f"
                        selectByMouse: true
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search applications…"
                            font: search.font
                            color: Theme.textFaint
                            visible: search.text === ""
                        }
                    }

                    Text {
                        visible: search.text !== ""
                        text: "󰅖"
                        font.pixelSize: 12
                        color: clearMouse.containsMouse ? Theme.textPrimary : Theme.textMuted

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: search.text = ""
                        }
                    }
                }
            }

            // Filtered here rather than in the delegate so the list height and
            // the "no matches" note both see the same result.
            readonly property var matches: {
                var q = search.text.toLowerCase().trim();
                var out = [];
                var pinnedClasses = {};
                for (var j = 0; j < Config.pinned.length; j++)
                    pinnedClasses[Config.pinned[j]["class"]] = true;
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
                implicitHeight: 190
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
                                // Layout.preferred, not implicit: an Image's
                                // implicit size is read-only (it comes from the
                                // source), so assigning it is ignored.
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
                            onClicked: Config.addPinned(modelData)
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
        title: "DOCK SIZE"
        section: "dock"
        keys: ["iconSlot", "iconSize", "dockPadding", "radiusPanel", "cornerFillet", "edgeLine"]

        SliderRow { section: "dock"; key: "iconSlot"; label: "Slot width"; from: 36; to: 84; suffix: " px" }
        SliderRow { section: "dock"; key: "iconSize"; label: "Icon size"; from: 20; to: 64; suffix: " px" }
        SliderRow { section: "dock"; key: "dockPadding"; label: "Padding"; from: 4; to: 24; suffix: " px" }
        SliderRow { section: "dock"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 32; suffix: " px" }
        SliderRow { section: "dock"; key: "cornerFillet"; label: "Rail fillet"; from: 0; to: 40; suffix: " px" }
        SliderRow { section: "dock"; key: "edgeLine"; label: "Edge rail"; from: 0; to: 12; suffix: " px" }
    }

    Card {
        title: "DOCK REVEAL"
        subtitle: "The strip along the bottom edge that opens the dock"
        section: "dock"
        keys: ["hotspotHeight", "hotspotWidthFraction"]

        SliderRow { section: "dock"; key: "hotspotHeight"; label: "Trigger height"; from: 2; to: 40; suffix: " px" }
        SliderRow {
            section: "dock"; key: "hotspotWidthFraction"; label: "Trigger width"
            from: 0.05; to: 1.0; step: 0.05; decimals: 2; suffix: " of screen"
        }
    }

    Card {
        title: "WINDOW PREVIEWS"
        subtitle: "Live thumbnails shown when you hover a running app"
        section: "dock"
        keys: ["previewTileW", "previewTileH", "previewMaxTiles"]

        SliderRow { section: "dock"; key: "previewTileW"; label: "Tile width"; from: 100; to: 320; step: 4; suffix: " px" }
        SliderRow { section: "dock"; key: "previewTileH"; label: "Tile height"; from: 70; to: 220; step: 2; suffix: " px" }
        SliderRow { section: "dock"; key: "previewMaxTiles"; label: "Max tiles"; from: 1; to: 10 }
    }
}
