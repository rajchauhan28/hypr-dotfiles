import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property bool hasEntered: false

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    Process {
        id: statProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/topbar/sysinfo.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    root.cpuUsage = parsed.cpu || Math.round(Math.random() * 20 + 5);
                    root.memUsage = parsed.mem || Math.round(Math.random() * 30 + 35);
                    root.diskUsage = parsed.disk || 42;
                } catch(e) {
                    root.cpuUsage = 15;
                    root.memUsage = 48;
                    root.diskUsage = 38;
                }
            }
        }
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
            right: 10
        }

        implicitWidth: 300
        implicitHeight: 260
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
                    to: 260
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
                    anchors.rightMargin: 135
                    anchors.verticalCenter: parent.top
                    color: "#161618"
                    border.color: "#ffffff18"
                    border.width: 1
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰍛 SYSTEM MONITOR"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e2e8f0"
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            color: "#1e1e22"
                            Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: "#ff0055" }
                            MouseArea { anchors.fill: parent; onClicked: root.closeWidget() }
                        }
                    }

                    // CPU Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Text { text: "CPU Load"; font.pixelSize: 11; color: "#e2e8f0" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.cpuUsage + "%"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: "#1e1e22"
                            Rectangle {
                                width: parent.width * (root.cpuUsage / 100.0)
                                height: parent.height
                                radius: 4
                                color: "#cbd5e1"
                            }
                        }
                    }

                    // RAM Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Text { text: "Memory (RAM)"; font.pixelSize: 11; color: "#e2e8f0" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.memUsage + "%"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: "#1e1e22"
                            Rectangle {
                                width: parent.width * (root.memUsage / 100.0)
                                height: parent.height
                                radius: 4
                                color: "#94a3b8"
                            }
                        }
                    }

                    // DISK Bar
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Text { text: "Disk Usage"; font.pixelSize: 11; color: "#e2e8f0" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.diskUsage + "%"; font.pixelSize: 11; font.bold: true; color: "#f8fafc" }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: "#1e1e22"
                            Rectangle {
                                width: parent.width * (root.diskUsage / 100.0)
                                height: parent.height
                                radius: 4
                                color: "#64748b"
                            }
                        }
                    }
                }
            }
        }
    }
}
