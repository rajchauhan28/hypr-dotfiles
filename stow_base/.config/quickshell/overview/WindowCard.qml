import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: winCard

    required property var winData
    signal closeRequested(string address)
    signal focusRequested(string address)

    implicitHeight: 40
    radius: 10
    color: winMouse.containsMouse ? "#282836" : "#1a1a22"
    border.color: winMouse.containsMouse ? "#ffffff40" : "#ffffff12"
    border.width: 1

    scale: winMouse.pressed ? 0.97 : (winMouse.containsMouse ? 1.03 : 1.0)
    Behavior on scale {
        SpringAnimation {
            spring: 4.8
            damping: 0.55
            epsilon: 0.005
        }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.animFast }
    }

    function getAppIcon(appClass) {
        var cls = (appClass || "").toLowerCase();
        if (cls.indexOf("ghostty") !== -1 || cls.indexOf("term") !== -1 || cls.indexOf("alacritty") !== -1 || cls.indexOf("kitty") !== -1) return "💻";
        if (cls.indexOf("brave") !== -1 || cls.indexOf("firefox") !== -1 || cls.indexOf("chrome") !== -1) return "🌐";
        if (cls.indexOf("code") !== -1 || cls.indexOf("vsc") !== -1) return "📝";
        if (cls.indexOf("obsidian") !== -1) return "🔮";
        if (cls.indexOf("discord") !== -1 || cls.indexOf("webcord") !== -1) return "💬";
        if (cls.indexOf("spotify") !== -1) return "🎵";
        if (cls.indexOf("file") !== -1 || cls.indexOf("thunar") !== -1 || cls.indexOf("dolphin") !== -1) return "📁";
        if (cls.indexOf("rdp") !== -1) return "🖥️";
        return "📦";
    }

    MouseArea {
        id: winMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                winCard.closeRequested(winCard.winData.address);
            } else {
                winCard.focusRequested(winCard.winData.address);
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Text {
                text: winCard.getAppIcon(winCard.winData.class)
                font.pixelSize: 14
            }

            Text {
                text: winCard.winData.title || winCard.winData.class || "Window"
                font.pixelSize: 11
                font.bold: true
                color: "#f8fafc"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: 6
                color: closeMouse.containsMouse ? "#ef4444" : "#ffffff10"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 10
                    color: closeMouse.containsMouse ? "#ffffff" : "#a1a1aa"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        winCard.closeRequested(winCard.winData.address);
                    }
                }
            }
        }
    }
}
