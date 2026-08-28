import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root

    property string dayStr: "SUNDAY"
    property string dateStr: "01 MAY 2022"
    property string timeStr: "- 08:22 PM -"

    // Unified Pywal Color Scheme
    property color fgColor: "#f8fafc"
    property color bgColor: "#1a0b0b"
    property color accentColor: "#cbd5e1"

    FontLoader {
        id: anuratiFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Anurati/Anurati-Regular.otf"
    }

    FontLoader {
        id: audiowideFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Google Fonts/Audiowide/Audiowide_Regular.22.ttf"
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var wal = JSON.parse(text());
                if (wal && wal.special && wal.special.foreground) {
                    root.fgColor = wal.special.foreground;
                }
                if (wal && wal.special && wal.special.background) {
                    root.bgColor = wal.special.background;
                }
                if (wal && wal.colors) {
                    root.accentColor = wal.colors.color4 || wal.colors.color6 || wal.colors.color1 || root.fgColor;
                }
            } catch(e) {}
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            root.dayStr = Qt.formatDateTime(d, "dddd").toUpperCase();
            root.dateStr = Qt.formatDateTime(d, "dd MMMM yyyy").toUpperCase();
            root.timeStr = "- " + Qt.formatDateTime(d, "hh:mm AP") + " -";
        }
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-desktop-clock"
        exclusiveZone: -1

        mask: Region {}

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -120
            spacing: 14

            // LINE 1: DAY IN ANURATI FONT
            Item {
                implicitWidth: dayText.implicitWidth + 10
                implicitHeight: dayText.implicitHeight + 10
                Layout.alignment: Qt.AlignHCenter

                // Deep contrast text shadow
                Text {
                    text: root.dayStr
                    font.family: (anuratiFont.name !== "") ? anuratiFont.name : "Anurati"
                    font.pixelSize: 85
                    font.bold: true
                    font.letterSpacing: 8
                    color: Qt.rgba(0, 0, 0, 0.75)
                    x: 3
                    y: 3
                }

                Text {
                    id: dayText
                    text: root.dayStr
                    font.family: (anuratiFont.name !== "") ? anuratiFont.name : "Anurati"
                    font.pixelSize: 85
                    font.bold: true
                    font.letterSpacing: 8
                    color: root.fgColor
                }
            }

            // LINE 2: DATE IN CLEAR HIGH-READABILITY FONT
            Item {
                implicitWidth: dateText.implicitWidth + 10
                implicitHeight: dateText.implicitHeight + 10
                Layout.alignment: Qt.AlignHCenter

                // Deep contrast text shadow
                Text {
                    text: root.dateStr
                    font.family: (audiowideFont.name !== "") ? audiowideFont.name : "Adwaita Sans, Cantarell, Sans-Serif"
                    font.pixelSize: 24
                    font.bold: true
                    font.letterSpacing: 6
                    color: Qt.rgba(0, 0, 0, 0.8)
                    x: 2
                    y: 2
                }

                Text {
                    id: dateText
                    text: root.dateStr
                    font.family: (audiowideFont.name !== "") ? audiowideFont.name : "Adwaita Sans, Cantarell, Sans-Serif"
                    font.pixelSize: 24
                    font.bold: true
                    font.letterSpacing: 6
                    color: root.fgColor
                }
            }

            // LINE 3: TIME IN CLEAR HIGH-READABILITY FONT
            Item {
                implicitWidth: timeText.implicitWidth + 10
                implicitHeight: timeText.implicitHeight + 10
                Layout.alignment: Qt.AlignHCenter

                // Deep contrast text shadow
                Text {
                    text: root.timeStr
                    font.family: (audiowideFont.name !== "") ? audiowideFont.name : "Adwaita Sans, Cantarell, Sans-Serif"
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: 4
                    color: Qt.rgba(0, 0, 0, 0.8)
                    x: 2
                    y: 2
                }

                Text {
                    id: timeText
                    text: root.timeStr
                    font.family: (audiowideFont.name !== "") ? audiowideFont.name : "Adwaita Sans, Cantarell, Sans-Serif"
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: 4
                    color: root.fgColor
                }
            }
        }
    }
}
