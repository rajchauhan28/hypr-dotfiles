import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    // Data Models
    property var activeWifi: null
    property var wifiNetworks: []
    property var btStatus: ({ powered: false, connected_devices: [] })
    property var btDevices: []
    property bool isScanning: false

    // Periodic Data Fetching
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiProc.running = true;
            btProc.running = true;
        }
    }

    Process {
        id: wifiProc
        command: ["auralink", "fullstatus"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    root.activeWifi = parsed.status.active_network;
                    root.wifiNetworks = parsed.available_networks || [];
                } catch(e) {}
            }
        }
    }

    Process {
        id: btProc
        command: ["auralink-bt", "fullstatus"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    root.btStatus = parsed.status || { powered: false, connected_devices: [] };
                    root.btDevices = parsed.all_devices || [];
                } catch(e) {}
            }
        }
    }

    // Helper Command Runner
    function runCmd(args) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = args;
        p.running = true;
    }

    PanelWindow {
        id: popupWindow
        anchors {
            top: true
            right: true
        }
        margins {
            top: 48
            right: 12
        }

        implicitWidth: 380
        implicitHeight: 520
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#e6121214"
            border.color: "#ffffff18"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "AURA // LINK"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#e2e8f0"
                            font.letterSpacing: 2
                        }
                        Text {
                            text: root.activeWifi ? ("CONNECTED: " + root.activeWifi.ssid) : "DISCONNECTED"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#94a3b8"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Header Buttons
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: "#1e1e22"
                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.pixelSize: 16
                            color: "#f8fafc"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                wifiProc.running = true;
                                btProc.running = true;
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: "#1e1e22"
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.pixelSize: 16
                            color: "#ff0055"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: popupWindow.visible = false
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#ffffff15"
                }

                // Main Scrollable Body
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 16

                        // --- WI-FI CARD ---
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: wifiCol.implicitHeight + 24
                            radius: 14
                            color: "#1e1e22"
                            border.color: "#ffffff15"
                            border.width: 1

                            ColumnLayout {
                                id: wifiCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "󰤨 WI-FI"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#e2e8f0"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        implicitWidth: 60
                                        implicitHeight: 24
                                        radius: 6
                                        color: "#26262a"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Scan"
                                            font.pixelSize: 11
                                            color: "#e2e8f0"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: root.runCmd(["auralink", "rescan"])
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: root.wifiNetworks.slice(0, 5)
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 36
                                            radius: 8
                                            color: modelData.connected ? "#ffffff18" : "#161618"
                                            border.color: modelData.connected ? "#f8fafc" : "transparent"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8
                                                Text {
                                                    text: modelData.connected ? "󰤨" : "󰤢"
                                                    font.pixelSize: 14
                                                    color: modelData.connected ? "#f8fafc" : "#94a3b8"
                                                }
                                                Text {
                                                    text: modelData.ssid
                                                    font.pixelSize: 12
                                                    font.bold: modelData.connected
                                                    color: "#f8fafc"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.signal + "%"
                                                    font.pixelSize: 10
                                                    color: "#94a3b8"
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (!modelData.connected) {
                                                        root.runCmd(["auralink", "connect", modelData.ssid]);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- BLUETOOTH CARD ---
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: btCol.implicitHeight + 24
                            radius: 14
                            color: "#1e1e22"
                            border.color: "#ffffff15"
                            border.width: 1

                            ColumnLayout {
                                id: btCol
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "󰂯 BLUETOOTH"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#e2e8f0"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.btStatus.powered ? "POWER: ON" : "POWER: OFF"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: root.btStatus.powered ? "#10b981" : "#ef4444"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: root.btStatus.connected_devices || []
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 36
                                            radius: 8
                                            color: "#10b98115"
                                            border.color: "#10b98180"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8
                                                Text {
                                                    text: "󰂱"
                                                    font.pixelSize: 14
                                                    color: "#10b981"
                                                }
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: "#f8fafc"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.battery ? (modelData.battery + "%") : ""
                                                    font.pixelSize: 10
                                                    color: "#10b981"
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.runCmd(["auralink-bt", "disconnect", modelData.address])
                                            }
                                        }
                                    }

                                    Text {
                                        visible: (root.btStatus.connected_devices || []).length === 0
                                        text: "No Bluetooth devices connected"
                                        font.pixelSize: 11
                                        color: "#64748b"
                                    }
                                }
                            }
                        }

                        // --- QUICK CONTROLS BAR ---
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: 10
                                color: "#ffffff18"
                                border.color: "#ffffff30"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "Open Full GUI"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#f8fafc"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.runCmd(["auralink", "popup"]);
                                        popupWindow.visible = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
