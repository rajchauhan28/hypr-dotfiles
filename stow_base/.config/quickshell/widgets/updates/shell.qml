import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property var updateList: []
    property int updateCount: 0

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updatesProc.running = true
    }

    Process {
        id: updatesProc
        command: ["bash", "-c", "{ checkupdates 2>/dev/null; yay -Qua 2>/dev/null; } | sort -u"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split('\n').filter(l => l.length > 0);
                var parsed = [];
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i];
                    var parts = l.split(/\s+/);
                    if (parts.length >= 4 && parts[2] === "->") {
                        parsed.push({
                            name: parts[0],
                            oldVersion: parts[1],
                            newVersion: parts[3]
                        });
                    } else if (parts.length >= 2) {
                        parsed.push({
                            name: parts[0],
                            oldVersion: "installed",
                            newVersion: parts[1]
                        });
                    } else {
                        parsed.push({
                            name: l,
                            oldVersion: "",
                            newVersion: "update available"
                        });
                    }
                }
                root.updateList = parsed;
                root.updateCount = parsed.length;
            }
        }
    }

    function runCmd(args) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = args;
        p.running = true;
    }

    function closeWidget() {
        closeAnim.start();
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: glassPane; property: "height"; to: 0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: glassPane; property: "opacity"; to: 0; duration: 150 }
        }
        ScriptAction { script: Qt.quit() }
    }

    PanelWindow {
        id: win
        anchors {
            top: true
            right: true
        }
        margins {
            top: 15
            right: 480
        }

        implicitWidth: 420
        implicitHeight: 520
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: glassPane
            anchors.fill: parent
            radius: 20
            color: "#e6121214"
            border.color: "#ffffff18"
            border.width: 1

            NumberAnimation on height {
                from: 0
                to: 520
                duration: 250
                easing.type: Easing.OutCubic
            }

            NumberAnimation on opacity {
                from: 0.0
                to: 1.0
                duration: 200
            }

            // Connection Pointer arrow
            Rectangle {
                width: 14
                height: 14
                rotation: 45
                anchors.right: parent.right
                anchors.rightMargin: 175
                anchors.verticalCenter: parent.top
                color: "#161618"
                border.color: "#ffffff18"
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "󰚰 SYSTEM UPDATES"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#e2e8f0"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.updateCount + " PACKAGES PENDING"
                        font.pixelSize: 10
                        font.bold: true
                        color: root.updateCount > 0 ? "#cbd5e1" : "#10b981"
                    }
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 8
                        color: "#1e1e22"
                        Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: "#ff0055" }
                        MouseArea { anchors.fill: parent; onClicked: root.closeWidget() }
                    }
                }

                ListView {
                    id: updateListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: root.updateList

                    delegate: Rectangle {
                        required property var modelData
                        width: updateListView.width
                        implicitHeight: 46
                        radius: 10
                        color: "#1e1e22"
                        border.color: "#ffffff15"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 7
                                color: "#26262a"
                                Text {
                                    anchors.centerIn: parent
                                    text: "📦"
                                    font.pixelSize: 14
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#f8fafc"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: modelData.oldVersion
                                        font.pixelSize: 10
                                        color: "#94a3b8"
                                    }
                                    Text {
                                        text: "➔"
                                        font.pixelSize: 10
                                        color: "#64748b"
                                    }
                                    Text {
                                        text: modelData.newVersion
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#10b981"
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.updateCount === 0
                        text: "System is fully up to date! 🎉"
                        font.pixelSize: 12
                        color: "#10b981"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 10
                        color: "#1e1e22"
                        border.color: "#ffffff15"

                        Text {
                            anchors.centerIn: parent
                            text: "Update Now"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#f8fafc"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.runCmd(["ghostty", "-e", "bash", "-c", "yay -Syu; echo 'Press Enter to exit...'; read"]);
                                root.closeWidget();
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 10
                        color: "#f8fafc"

                        Text {
                            anchors.centerIn: parent
                            text: "⚡ Rate & Update"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#09090b"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.runCmd(["ghostty", "-e", "bash", "-c", "rate-mirrors --protocol=https arch | sudo tee /etc/pacman.d/mirrorlist && yay -Syu; echo 'Press Enter to exit...'; read"]);
                                root.closeWidget();
                            }
                        }
                    }
                }
            }
        }
    }
}
