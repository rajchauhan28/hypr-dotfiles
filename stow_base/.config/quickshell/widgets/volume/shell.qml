import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property int volume: 50
    property bool isMuted: false
    property string activeDevice: "Default Audio Output"
    property var sinkList: []
    property var sourceList: []
    property bool hasEntered: false

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            volProc.running = true;
            devProc.running = true;
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(' ');
                if (parts.length >= 2) {
                    var val = parseFloat(parts[1]);
                    root.volume = Math.round(val * 100);
                    root.isMuted = data.includes("[MUTED]");
                }
            }
        }
    }

    Process {
        id: devProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/widgets/volume/audio_info.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    root.activeDevice = parsed.active_sink_description || "Default Audio Device";
                    root.sinkList = parsed.sinks || [];
                    root.sourceList = parsed.sources || [];
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
            right: true
        }
        margins {
            top: 15
            right: 350
        }

        implicitWidth: 360
        implicitHeight: 440
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
                    to: 440
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
                    anchors.rightMargin: 140
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
                            text: "󰕾 AUDIO CONTROL"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e2e8f0"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.isMuted ? "MUTED" : (root.volume + "%")
                            font.pixelSize: 12
                            font.bold: true
                            color: root.isMuted ? "#ef4444" : "#f8fafc"
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

                    // Active Device Banner
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 10
                        color: "#1e1e22"
                        border.color: "#ffffff18"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Text { text: "🎧"; font.pixelSize: 14 }
                            Text {
                                text: root.activeDevice
                                font.pixelSize: 11
                                font.bold: true
                                color: "#f8fafc"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Volume Slider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: 10
                            color: root.isMuted ? "#ef444433" : "#1e1e22"
                            border.color: root.isMuted ? "#ef4444" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: root.isMuted ? "󰝟" : "󰕾"
                                font.pixelSize: 16
                                color: root.isMuted ? "#ef4444" : "#f8fafc"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.runCmd(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                            }
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: root.volume
                            onMoved: {
                                var target = Math.round(value) / 100.0;
                                root.runCmd(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", target.toString()]);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#ffffff15"
                    }

                    // Output Devices List Header
                    Text {
                        text: "OUTPUT DEVICES"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#94a3b8"
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 120
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.sinkList
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    radius: 8
                                    color: modelData.active ? "#ffffff18" : "#1e1e22"
                                    border.color: modelData.active ? "#f8fafc" : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6
                                        Text {
                                            text: modelData.active ? "●" : "○"
                                            font.pixelSize: 10
                                            color: modelData.active ? "#f8fafc" : "#64748b"
                                        }
                                        Text {
                                            text: modelData.description
                                            font.pixelSize: 11
                                            color: modelData.active ? "#f8fafc" : "#94a3b8"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.runCmd(["pactl", "set-default-sink", modelData.name]);
                                            devProc.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 8
                        color: "#1e1e22"

                        Text {
                            anchors.centerIn: parent
                            text: "Full Audio Settings (Pavucontrol)"
                            font.pixelSize: 11
                            color: "#e2e8f0"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.runCmd(["pavucontrol"]);
                                root.closeWidget();
                            }
                        }
                    }
                }
            }
        }
    }
}
