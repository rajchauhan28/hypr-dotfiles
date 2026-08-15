import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page
    spacing: Theme.gap

    readonly property string selectedIcon: Config.get("lockscreen", "icon")
    property string importError: ""

    FileDialog {
        id: avatarDialog
        title: "Choose a lockscreen profile image"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)"]
        onAccepted: {
            page.importError = "";
            avatarImporter.command = [
                "python3",
                "/home/reign/.config/quickshell/settings/avatar.py",
                selectedFile.toString()
            ];
            avatarImporter.running = true;
        }
    }

    Process {
        id: avatarImporter
        stdout: SplitParser {
            onRead: output => {
                var imported = output.trim();
                if (imported !== "")
                    Config.set("lockscreen", "icon", imported);
            }
        }
        stderr: SplitParser {
            onRead: output => page.importError = output.trim()
        }
        onExited: code => {
            if (code !== 0 && page.importError === "")
                page.importError = "The image could not be imported.";
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Profile icon"

        RowLayout {
            Layout.fillWidth: true
            spacing: 22

            Rectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 112
                radius: 56
                color: "#18181d"
                border.color: Theme.accent
                border.width: 2
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 10
                    source: Config.osIcon
                    fillMode: Image.PreserveAspectFit
                    visible: source.toString() !== ""
                }

                Image {
                    id: customPreview
                    anchors.fill: parent
                    source: page.selectedIcon
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(256, 256)
                    visible: source.toString() !== "" && status !== Image.Error
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰌾"
                    font.pixelSize: 48
                    color: Theme.textMuted
                    visible: Config.osIcon === ""
                             && (page.selectedIcon === "" || customPreview.status === Image.Error)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: page.selectedIcon !== "" ? "Custom profile image" : Config.osName + " logo"
                    color: Theme.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: page.selectedIcon !== ""
                          ? "This image is copied into Quickshell's assets and shown at the center of the lockscreen."
                          : "No custom image is selected, so the operating-system logo is used automatically."
                    color: Theme.textSecondary
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    spacing: 8

                    Rectangle {
                        implicitWidth: chooseLabel.implicitWidth + 26
                        implicitHeight: 34
                        radius: Theme.radiusSmall
                        color: chooseMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.color: Theme.border

                        Text {
                            id: chooseLabel
                            anchors.centerIn: parent
                            text: page.selectedIcon === "" ? "Choose image" : "Replace image"
                            color: Theme.textPrimary
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: chooseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: avatarDialog.open()
                        }
                    }

                    Rectangle {
                        implicitWidth: defaultLabel.implicitWidth + 26
                        implicitHeight: 34
                        radius: Theme.radiusSmall
                        color: defaultMouse.containsMouse ? Theme.cardHover : "transparent"
                        border.color: Theme.border
                        visible: page.selectedIcon !== ""

                        Text {
                            id: defaultLabel
                            anchors.centerIn: parent
                            text: "Use OS logo"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: defaultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.set("lockscreen", "icon", "")
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.importError
                    color: Theme.danger
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Lockscreen background"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "The lockscreen mirrors the current Walllust wallpaper. Images remain still; mpvpaper videos continue as a muted looping background."
                color: Theme.textPrimary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "A translucent dark layer and glass controls sit above the wallpaper. Application windows are never captured or shown through the secure lock surface."
                color: Theme.textSecondary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }
}
