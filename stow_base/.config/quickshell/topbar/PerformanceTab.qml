import QtQuick
import QtQuick.Layouts

Item {
    id: tab

    property var stats: ({})
    property var cpuHistory: []
    property var gpuHistory: []
    property var vramHistory: []
    property var systemTempHistory: []
    property var gpuTempHistory: []
    property var networkDownHistory: []
    property var networkUpHistory: []
    property int gpuPage: 0

    function rate(value) {
        var n = Number(value) || 0;
        if (n >= 1024)
            return (n / 1024).toFixed(n >= 10240 ? 0 : 1) + " MiB/s";
        return n.toFixed(n >= 100 ? 0 : 1) + " KiB/s";
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // ---- CPU: big readout + history + per-thread activity ---------
        Card {
            Layout.preferredWidth: 390
            Layout.minimumWidth: 390
            Layout.maximumWidth: 390
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: -2
                        Text {
                            text: "PROCESSOR"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            color: Theme.textMuted
                        }
                        Text {
                            text: (tab.stats.cores || 0) + " threads  ·  load "
                                  + (tab.stats.load !== undefined ? tab.stats.load : "--")
                            font.pixelSize: 10
                            color: Theme.textFaint
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (tab.stats.cpu || 0) + "%"
                        font.pixelSize: 28
                        font.bold: true
                        color: Theme.meterColor(tab.stats.cpu || 0)
                    }
                }

                MiniGraph {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    series: [tab.cpuHistory]
                    lineColors: [Theme.accent]

                    Text {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 7
                        text: (tab.stats.temp || 0) + "°C"
                        font.pixelSize: 10
                        font.bold: true
                        color: (tab.stats.temp || 0) >= 80 ? Theme.danger : Theme.textMuted
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Text {
                        text: "PER CORE"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.textMuted
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "logical threads"
                        font.pixelSize: 9
                        color: Theme.textFaint
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 90
                    Layout.maximumHeight: 90
                    spacing: 3

                    Repeater {
                        model: tab.stats.coreLoad || []
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 3
                            color: Theme.cardAlt
                            border.color: Theme.border
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 1
                                height: Math.max(2, (parent.height - 2)
                                                   * Math.min(100, modelData) / 100)
                                radius: 2
                                color: Theme.meterColor(modelData)
                                Behavior on height {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                    }
                }
            }
        }

        // ---- Memory, storage, graphics and diagnostic charts ---------
        Card {
            Layout.fillWidth: true
            Layout.minimumWidth: 360
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                spacing: 8

                Text {
                    text: "RESOURCES"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    color: Theme.textMuted
                }

                Meter {
                    Layout.fillWidth: true
                    label: "Memory"
                    value: tab.stats.mem || 0
                    valueText: (tab.stats.memUsed || 0) + " / " + (tab.stats.memTotal || 0) + " GiB"
                }
                Meter {
                    Layout.fillWidth: true
                    label: "Swap"
                    value: tab.stats.swap || 0
                }
                Meter {
                    Layout.fillWidth: true
                    label: "Disk  /"
                    value: tab.stats.disk || 0
                    valueText: (tab.stats.diskUsed || 0) + " / " + (tab.stats.diskTotal || 0) + " GB"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "GRAPHICS"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.textMuted
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: tab.stats.gpu ? (tab.stats.gpu.asleep ? "suspended" : tab.stats.gpu.name) : ""
                        font.pixelSize: 10
                        color: Theme.textFaint
                        elide: Text.ElideRight
                        Layout.maximumWidth: 220
                    }
                }

                Text {
                    visible: tab.stats.gpu !== undefined && tab.stats.gpu.present && tab.stats.gpu.asleep
                    text: "Discrete GPU powered down — telemetry paused."
                    font.pixelSize: 10
                    color: Theme.textFaint
                }
                Meter {
                    Layout.fillWidth: true
                    visible: tab.stats.gpu !== undefined && tab.stats.gpu.present && !tab.stats.gpu.asleep
                    label: "GPU"
                    value: tab.stats.gpu ? tab.stats.gpu.util : 0
                    valueText: (tab.stats.gpu ? tab.stats.gpu.util : 0) + "%  ·  "
                               + (tab.stats.gpu ? tab.stats.gpu.temp : 0) + "°C"
                }
                Meter {
                    Layout.fillWidth: true
                    visible: tab.stats.gpu !== undefined && tab.stats.gpu.present && !tab.stats.gpu.asleep
                    label: "VRAM"
                    value: tab.stats.gpu && tab.stats.gpu.memTotal > 0
                           ? 100 * tab.stats.gpu.memUsed / tab.stats.gpu.memTotal : 0
                    valueText: (tab.stats.gpu ? tab.stats.gpu.memUsed : 0) + " / "
                               + (tab.stats.gpu ? tab.stats.gpu.memTotal : 0) + " MiB"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 6

                    Repeater {
                        model: [
                            { label: "CPU LOAD (1m)", value: (tab.stats.load !== undefined ? tab.stats.load : "--") + "" },
                            { label: "TEMPERATURE", value: (tab.stats.temp || 0) + " °C" },
                            { label: "THREADS", value: (tab.stats.cores || 0) + "" },
                            { label: "DISK FREE", value: ((tab.stats.diskTotal || 0) - (tab.stats.diskUsed || 0)) + " GB" },
                            { label: "SWAP USED", value: (tab.stats.swap || 0) + " %" },
                            { label: "BATTERY", value: tab.stats.battery && tab.stats.battery.present
                                                       ? tab.stats.battery.capacity + "%  " + tab.stats.battery.status
                                                       : "none" }
                        ]
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: modelData.label
                                font.pixelSize: 8
                                font.bold: true
                                color: Theme.textFaint
                            }
                            Text {
                                text: modelData.value
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 112
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: Theme.cardAlt
                        border.color: Theme.border
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "NETWORK"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Theme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "↓ " + tab.rate(tab.stats.network ? tab.stats.network.down : 0)
                                          + "   ↑ " + tab.rate(tab.stats.network ? tab.stats.network.up : 0)
                                    font.pixelSize: 8
                                    color: Theme.textSecondary
                                }
                            }
                            MiniGraph {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                series: [tab.networkDownHistory, tab.networkUpHistory]
                                lineColors: [Theme.accent, Theme.good]
                                autoMaximum: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSmall
                        color: Theme.cardAlt
                        border.color: Theme.border
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "TEMPERATURES"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1
                                    color: Theme.textMuted
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "SYS " + (tab.stats.systemTemp || 0)
                                          + "°   GPU " + (tab.stats.gpu ? tab.stats.gpu.temp : 0) + "°"
                                    font.pixelSize: 8
                                    color: Theme.textSecondary
                                }
                            }
                            MiniGraph {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                series: [tab.systemTempHistory, tab.gpuTempHistory]
                                lineColors: [Theme.textSecondary, Theme.good]
                                maximum: 110
                                fillFirst: false
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            { label: "UPTIME", value: tab.stats.uptime || "--" },
                            { label: "KERNEL", value: tab.stats.kernel || "--" }
                        ]
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { text: modelData.label; font.pixelSize: 8; font.bold: true; color: Theme.textFaint }
                            Text {
                                text: modelData.value
                                font.pixelSize: 9
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // ---- Processes + paged GPU detail ----------------------------
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.minimumWidth: 300
            Layout.maximumWidth: 300
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: Theme.gap

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    spacing: 7
                    Text {
                        text: "TOP BY MEMORY"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.textMuted
                    }
                    Repeater {
                        model: tab.stats.procs || []
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: modelData.name
                                font.pixelSize: 10
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.mem + " MB"
                                font.pixelSize: 9
                                font.bold: true
                                color: Theme.textSecondary
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 218

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: ["GPU LOAD", "VRAM USAGE", "GPU COMPUTE"][tab.gpuPage]
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.1
                            color: Theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: tab.stats.gpu && tab.stats.gpu.asleep ? "suspended"
                                  : (tab.gpuPage === 0 ? (tab.stats.gpu ? tab.stats.gpu.util : 0) + "%"
                                     : tab.gpuPage === 1 ? (tab.stats.gpu ? tab.stats.gpu.memUsed : 0) + " MiB"
                                     : "CUDA " + (tab.stats.gpu ? tab.stats.gpu.computeCapability : "--"))
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MiniGraph {
                            anchors.fill: parent
                            visible: tab.gpuPage === 0
                            series: [tab.gpuHistory]
                            lineColors: [Theme.good]
                        }
                        MiniGraph {
                            anchors.fill: parent
                            visible: tab.gpuPage === 1
                            series: [tab.vramHistory]
                            lineColors: [Theme.warn]
                        }
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: tab.gpuPage === 2
                            spacing: 3
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: tab.stats.gpu ? tab.stats.gpu.name : "No discrete GPU"
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "CUDA compute capability  "
                                      + (tab.stats.gpu && tab.stats.gpu.computeCapability
                                         ? tab.stats.gpu.computeCapability : "unavailable")
                                font.pixelSize: 9
                                color: Theme.textSecondary
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (tab.stats.gpu ? tab.stats.gpu.temp : 0) + "°C  ·  "
                                      + (tab.stats.gpu ? tab.stats.gpu.memTotal : 0) + " MiB VRAM"
                                font.pixelSize: 9
                                color: Theme.textFaint
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 7
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                width: tab.gpuPage === index ? 18 : 6
                                height: 6
                                radius: 3
                                color: tab.gpuPage === index ? Theme.accent : Theme.textFaint
                                Behavior on width { NumberAnimation { duration: 180 } }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tab.gpuPage = index
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
