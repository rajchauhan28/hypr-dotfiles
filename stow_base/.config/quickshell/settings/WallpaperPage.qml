import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Grid of ~/Pictures/wallpapers/, click to apply via walllust-cli -- same
// backend ~/.config/hypr/wallpaper_switcher.sh uses, so the rotation keybind
// and this picker agree on where the current wallpaper lives.
ColumnLayout {
    id: page

    spacing: Theme.gap

    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/wallpapers"

    FolderListModel {
        id: files
        folder: "file://" + page.wallDir
        showDirs: false
        showHidden: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif"]
        sortField: FolderListModel.Name
    }

    Process {
        id: applyProc
        running: false
    }

    function apply(path) {
        // Same call wallpaper_switcher.sh makes; walllust-daemon handles the
        // transition and palette regeneration. Detached so a slow walllust run
        // cannot freeze the settings UI.
        Quickshell.execDetached(["sh", "-c",
            "walllust-cli set \"$1\" >/dev/null 2>&1",
            "sh", path]);
        page.currentPath = path;
    }

    property string currentPath: ""

    Card {
        title: "WALLPAPER"
        subtitle: page.wallDir.replace(Quickshell.env("HOME"), "~")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: files.count + " image" + (files.count === 1 ? "" : "s")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                }

                Rectangle {
                    implicitWidth: 110
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: shuffleMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: "Shuffle"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: shuffleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(
                            ["sh", "-c",
                             "~/.config/hypr/wallpaper_switcher.sh >/dev/null 2>&1 &"])
                    }
                }
            }

            // The grid itself. 4 columns, 16:9 tiles, scrolls vertically.
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.preferredHeight: 420
                clip: true
                model: files
                cellWidth: Math.max(140, Math.floor(width / 4))
                cellHeight: Math.round(cellWidth * 9 / 16)

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    required property string filePath
                    required property string fileName

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.radiusSmall
                        clip: true
                        color: Theme.cardAlt
                        border.width: page.currentPath === filePath ? 2 : 1
                        border.color: page.currentPath === filePath ? Theme.accent : Theme.border

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            // Tile-sized, not full-res: 400x225 covers the 4-col
                            // grid without blowing memory on 4K photos.
                            sourceSize.width: 400
                            sourceSize.height: 225
                            smooth: true
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 22
                            color: "#99000000"
                            visible: tileMouse.containsMouse
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                verticalAlignment: Text.AlignVCenter
                                text: fileName
                                color: "#ffffff"
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.apply(filePath)
                        }
                    }
                }
            }

            Text {
                visible: files.count === 0
                Layout.fillWidth: true
                text: "No images found. Drop files into " + page.wallDir + "."
                color: Theme.textSecondary
                font.pixelSize: 12
            }
        }
    }
}
