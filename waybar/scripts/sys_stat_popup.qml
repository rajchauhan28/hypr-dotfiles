import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    width: 360
    height: 480
    visible: true
    title: "System Status"
    color: "#282a36" // Dracula Background
    flags: Qt.Dialog

    property var cpuData: []
    property var ramData: []
    property int maxPoints: 40
    property color accentColor: "#bd93f9" // Dracula Purple
    property color accentColor2: "#50fa7b" // Dracula Green
    property color textColor: "#f8f8f2"
    property color secondaryTextColor: "#6272a4"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Header
        Text {
            text: "System Dashboard"
            font.pixelSize: 20
            font.bold: true
            color: textColor
            Layout.alignment: Qt.AlignHCenter
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: secondaryTextColor
            opacity: 0.5
        }

        // === Uptime & Temp ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            ColumnLayout {
                spacing: 5
                Layout.alignment: Qt.AlignHCenter
                Text { 
                    text: "Uptime"
                    color: secondaryTextColor
                    font.pixelSize: 12
                }
                Text { 
                    id: uptimeLabel
                    text: "--"
                    color: textColor
                    font.pixelSize: 16
                    font.bold: true
                }
            }
            
            Item { Layout.fillWidth: true } // Spacer

            ColumnLayout {
                spacing: 5
                Layout.alignment: Qt.AlignHCenter
                 Text { 
                    text: "CPU Temp"
                    color: secondaryTextColor
                    font.pixelSize: 12
                }
                Text { 
                    id: tempLabel
                    text: "--"
                    color: "#ff5555" // Red
                    font.pixelSize: 16
                    font.bold: true
                }
            }
        }
        
        // === CPU Graph ===
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            
            RowLayout {
                Layout.fillWidth: true
                Text { text: "CPU Usage"; color: secondaryTextColor; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text { id: cpuValueLabel; text: "0%"; color: accentColor2; font.pixelSize: 12; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#1e1f29" // Darker BG
                radius: 6
                clip: true

                Canvas {
                    id: cpuCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        if (cpuData.length < 2) return

                        ctx.strokeStyle = accentColor2
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        
                        // Draw line
                        for (var i = 0; i < cpuData.length; i++) {
                            var x = (i / (maxPoints - 1)) * width
                            var y = height - (cpuData[i] * height)
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                        
                        // Fill area
                        ctx.lineTo(width, height)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        var gradient = ctx.createLinearGradient(0, 0, 0, height)
                        gradient.addColorStop(0, Qt.rgba(80/255, 250/255, 123/255, 0.5))
                        gradient.addColorStop(1, "transparent")
                        ctx.fillStyle = gradient
                        ctx.fill()
                    }
                }
            }
        }

        // === RAM Graph ===
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            
            RowLayout {
                Layout.fillWidth: true
                Text { text: "RAM Usage"; color: secondaryTextColor; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text { id: ramValueLabel; text: "0%"; color: accentColor; font.pixelSize: 12; font.bold: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#1e1f29"
                radius: 6
                clip: true

                Canvas {
                    id: ramCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        if (ramData.length < 2) return

                        ctx.strokeStyle = accentColor
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var i = 0; i < ramData.length; i++) {
                            var x = (i / (maxPoints - 1)) * width
                            var y = height - (ramData[i] * height)
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                        
                         // Fill area
                        ctx.lineTo(width, height)
                        ctx.lineTo(0, height)
                        ctx.closePath()
                        var gradient = ctx.createLinearGradient(0, 0, 0, height)
                        gradient.addColorStop(0, Qt.rgba(189/255, 147/255, 249/255, 0.5))
                        gradient.addColorStop(1, "transparent")
                        ctx.fillStyle = gradient
                        ctx.fill()
                    }
                }
            }
        }
        
        // === Disk Usage Bar ===
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Disk Usage (Root)"; color: secondaryTextColor; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text { id: diskValueLabel; text: "0%"; color: "#ff79c6"; font.pixelSize: 12; font.bold: true }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: "#44475a"
                
                Rectangle {
                    id: diskBar
                    height: parent.height
                    width: 0 // Will be animated
                    radius: 4
                    color: "#ff79c6"
                    
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Bottom spacer
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: readStats()
    }

    function readStats() {
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "/tmp/sys_stats.json", false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) {
                var stats = JSON.parse(xhr.responseText);

                var cpu = Math.min(Math.max(stats.cpu / 100, 0), 1)
                var ram = Math.min(Math.max(stats.ram / 100, 0), 1)
                var disk = stats.disk !== undefined ? stats.disk : 0
                var temp = stats.temp !== null ? stats.temp : 0
                var uptime = stats.uptime !== undefined ? stats.uptime : "--"

                // Update Arrays
                cpuData.push(cpu)
                if (cpuData.length > maxPoints) cpuData.shift()
                
                ramData.push(ram)
                if (ramData.length > maxPoints) ramData.shift()

                // Update Labels
                cpuValueLabel.text = stats.cpu.toFixed(0) + "%"
                ramValueLabel.text = stats.ram.toFixed(0) + "%"
                diskValueLabel.text = disk.toFixed(0) + "%"
                
                if (temp !== null) tempLabel.text = temp.toFixed(0) + "°C"
                else tempLabel.text = "N/A"
                
                uptimeLabel.text = uptime

                // Update Disk Bar
                diskBar.width = (disk / 100) * diskBar.parent.width

                // Repaint Graphs
                cpuCanvas.requestPaint()
                ramCanvas.requestPaint()
            }
        } catch (e) {
            console.log("File read error:", e)
        }
    }

    Component.onCompleted: readStats()
}