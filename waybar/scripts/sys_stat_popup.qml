import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    width: 420
    height: 330
    visible: true
    title: "System Stats"
    color: "#282a36"

    property var cpuData: []
    property var ramData: []
    property int maxPoints: 60 // 60 seconds

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Text {
            text: "System Monitor"
            font.pixelSize: 22
            font.bold: true
            color: "#f8f8f2"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        // === CPU Graph ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 8
            color: "#1e1f29"
            border.color: "#44475a"
            border.width: 1

            Canvas {
                id: cpuCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#1e1f29"
                    ctx.fillRect(0, 0, width, height)

                    if (cpuData.length < 2) return

                    ctx.strokeStyle = "#50fa7b"
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (var i = 0; i < cpuData.length; i++) {
                        var x = (i / (cpuData.length - 1)) * width
                        var y = height - (cpuData[i] * height)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()

                    ctx.fillStyle = "#50fa7b"
                    ctx.font = "14px Sans"
                    ctx.fillText("CPU Usage", 10, 20)
                }
            }
        }

        // === RAM Graph ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 8
            color: "#1e1f29"
            border.color: "#44475a"
            border.width: 1

            Canvas {
                id: ramCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.fillStyle = "#1e1f29"
                    ctx.fillRect(0, 0, width, height)

                    if (ramData.length < 2) return

                    ctx.strokeStyle = "#bd93f9"
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (var i = 0; i < ramData.length; i++) {
                        var x = (i / (ramData.length - 1)) * width
                        var y = height - (ramData[i] * height)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()

                    ctx.fillStyle = "#bd93f9"
                    ctx.font = "14px Sans"
                    ctx.fillText("RAM Usage", 10, 20)
                }
            }
        }

        // === Temperature display ===
        Text {
            id: tempLabel
            text: "Temp: 50°C"
            font.pixelSize: 16
            color: "#ffb86c"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: readStats()
    }

    // Read system stats from JSON
    function readStats() {
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "/tmp/sys_stats.json", false); // Synchronous request
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) { // 0 for file://
                var stats = JSON.parse(xhr.responseText);

                var cpu = Math.min(Math.max(stats.cpu / 100, 0), 1)
                var ram = Math.min(Math.max(stats.ram / 100, 0), 1)
                var temp = stats.temp !== null ? stats.temp : 0

                cpuData.push(cpu)
                ramData.push(ram)
                if (cpuData.length > maxPoints) cpuData.shift()
                if (ramData.length > maxPoints) ramData.shift()

                if (temp !== null) {
                    tempLabel.text = "Temp: " + temp.toFixed(0) + "°C"
                } else {
                    tempLabel.text = "Temp: N/A"
                }
                cpuCanvas.requestPaint()
                ramCanvas.requestPaint()
            }
        } catch (e) {
            console.log("File read error:", e)
        }
    }

    Component.onCompleted: readStats()
}
