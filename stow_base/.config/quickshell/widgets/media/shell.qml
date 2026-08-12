import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property string title: "No Media Playing"
    property string artist: "Unknown Artist"
    property string album: ""
    property string status: "Stopped"
    property string artUrl: ""
    property bool hasEntered: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaProc.running = true
    }

    Process {
        id: mediaProc
        command: ["playerctl", "metadata", "--format", "{\"title\":\"{{title}}\",\"artist\":\"{{artist}}\",\"album\":\"{{album}}\",\"status\":\"{{status}}\",\"artUrl\":\"{{mpris:artUrl}}\"}"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var meta = JSON.parse(data);
                    root.title = meta.title || "No Media Playing";
                    root.artist = meta.artist || "Unknown Artist";
                    root.album = meta.album || "";
                    root.status = meta.status || "Stopped";
                    root.artUrl = meta.artUrl || "";
                } catch(e) {}
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
            left: true
        }
        margins {
            top: 15
            left: 16
        }

        implicitWidth: 340
        implicitHeight: 200
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                root.hasEntered = true;
            }
            onExited: {
                if (root.hasEntered) {
                    root.closeWidget();
                }
            }

            Rectangle {
                id: glassPane
                anchors.fill: parent
                radius: 20
                color: "#e6121214"
                border.color: "#ffffff18"
                border.width: 1

                NumberAnimation on height {
                    from: 0
                    to: 200
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
                    anchors.left: parent.left
                    anchors.leftMargin: 128
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
                            text: "󰎈 MEDIA PLAYER"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e2e8f0"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.status.toUpperCase()
                            font.pixelSize: 10
                            font.bold: true
                            color: root.status === "Playing" ? "#f8fafc" : "#94a3b8"
                        }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            color: "#1e1e22"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.pixelSize: 13
                                color: "#ff0055"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.closeWidget()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            implicitWidth: 70
                            implicitHeight: 70
                            radius: 14
                            color: "#1e1e22"
                            border.color: "#ffffff15"
                            Image {
                                anchors.fill: parent
                                source: root.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"
                                font.pixelSize: 30
                                color: "#64748b"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: root.title
                                font.pixelSize: 14
                                font.bold: true
                                color: "#f8fafc"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.artist
                                font.pixelSize: 12
                                color: "#94a3b8"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.album
                                font.pixelSize: 10
                                color: "#64748b"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 20

                        Rectangle {
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 19
                            color: "#1e1e22"
                            border.color: "#ffffff10"
                            Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: 16; color: "#e2e8f0" }
                            MouseArea { anchors.fill: parent; onClicked: root.runCmd(["playerctl", "previous"]) }
                        }

                        Rectangle {
                            implicitWidth: 46
                            implicitHeight: 46
                            radius: 23
                            color: "#f8fafc"
                            Text { anchors.centerIn: parent; text: root.status === "Playing" ? "󰏤" : "󰐊"; font.pixelSize: 22; color: "#09090b" }
                            MouseArea { anchors.fill: parent; onClicked: root.runCmd(["playerctl", "play-pause"]) }
                        }

                        Rectangle {
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 19
                            color: "#1e1e22"
                            border.color: "#ffffff10"
                            Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: 16; color: "#e2e8f0" }
                            MouseArea { anchors.fill: parent; onClicked: root.runCmd(["playerctl", "next"]) }
                        }
                    }
                }
            }
        }
    }
}
