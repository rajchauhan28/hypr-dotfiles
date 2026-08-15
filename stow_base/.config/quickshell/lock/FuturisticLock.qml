import QtQuick
import Quickshell.Io

Item {
    id: ui

    required property var controller

    property date now: new Date()
    readonly property real hubX: 0
    readonly property real hubY: height * 0.5
    readonly property real outerRadius: Math.min(height * 0.47, 560)
    readonly property real innerRadius: outerRadius * 0.72
    readonly property real clockContentX: outerRadius * 0.42
    readonly property real smoothSeconds: now.getSeconds() + now.getMilliseconds() / 1000
    readonly property real smoothMinutes: now.getMinutes() + smoothSeconds / 60

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: ui.now = new Date()
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
    }

    // The minute and second faces rotate continuously around the fixed hour.
    // Their low contrast keeps the wallpaper readable through the lock layer.
    ClockDial {
        dialRadius: ui.outerRadius
        x: ui.hubX - dialRadius
        y: ui.hubY - dialRadius
        value: ui.smoothSeconds
        tickColor: "#8af8fafc"
        labelColor: "#aef8fafc"
        tickLength: 13
        majorTickLength: 23
        labelSize: 16
        tickWidth: 2.2
        majorTickWidth: 4.5
        opacity: 0.68
    }

    ClockDial {
        dialRadius: ui.innerRadius
        x: ui.hubX - dialRadius
        y: ui.hubY - dialRadius
        value: ui.smoothMinutes
        tickColor: "#62f8fafc"
        labelColor: "#78f8fafc"
        tickLength: 8
        majorTickLength: 16
        labelSize: 13
        tickWidth: 2
        majorTickWidth: 4
        opacity: 0.52
    }

    Text {
        id: hourText
        x: ui.clockContentX - width / 2
        y: ui.hubY - height / 2 + 3
        text: Qt.formatTime(ui.now, "HH")
        color: "#f8fafc"
        font.family: "Audiowide"
        font.pixelSize: Math.min(104, ui.height * 0.095)
        font.weight: Font.Black
        font.letterSpacing: -4
    }

    // Watch-style windows sit on the three-o'clock axis of their rings.
    // The dials continue moving underneath them.
    Rectangle {
        x: ui.hubX + ui.outerRadius - width / 2
        y: ui.hubY - height / 2
        width: 78
        height: 46
        radius: 18
        color: "#d21a191d"
        border.width: 1
        border.color: "#30ffffff"

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(ui.now, "ss")
            color: "#f8fafc"
            font.family: "Audiowide"
            font.pixelSize: 21
            font.weight: Font.Black
            font.letterSpacing: 1.5
        }
    }

    Rectangle {
        x: ui.hubX + ui.innerRadius - width / 2
        y: ui.hubY - height / 2
        width: 72
        height: 42
        radius: 16
        color: "#d21a191d"
        border.width: 1
        border.color: "#30ffffff"

        Text {
            anchors.centerIn: parent
            text: Qt.formatTime(ui.now, "mm")
            color: "#f8fafc"
            font.family: "Audiowide"
            font.pixelSize: 19
            font.weight: Font.Black
            font.letterSpacing: 1.5
        }
    }

    Rectangle {
        id: passwordPill

        x: profileRail.x + (profileRail.width - width) / 2
        y: profileRail.y + 140
        width: Math.min(370, ui.width * 0.23)
        height: 64
        radius: height / 2
        visible: ui.controller.selectedUser === ui.controller.sessionUser
        color: "#a3141418"
        border.width: 1
        border.color: ui.controller.authFailed
                      ? Theme.danger
                      : (passwordInput.activeFocus ? "#28ffffff" : "#12ffffff")

        Behavior on border.color { ColorAnimation { duration: 160 } }

        TextInput {
            id: passwordInput

            x: 18
            width: parent.width - x - 18
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: TextInput.AlignVCenter
            color: "transparent"
            selectionColor: "transparent"
            selectedTextColor: "transparent"
            echoMode: TextInput.NoEcho
            inputMethodHints: Qt.ImhSensitiveData
            clip: true
            cursorVisible: false
            enabled: !ui.controller.authInProgress

            onTextChanged: ui.controller.currentPassword = text
            onAccepted: ui.controller.tryUnlock()

            Component.onCompleted: forceActiveFocus()

            Connections {
                target: ui.controller

                function onCurrentPasswordChanged() {
                    if (passwordInput.text !== ui.controller.currentPassword)
                        passwordInput.text = ui.controller.currentPassword;
                }

                function onProfileChanged() {
                    passwordInput.forceActiveFocus();
                }
            }
        }

        Item {
            id: passwordGlyphs

            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 18
            height: 24

            readonly property int glyphCount:
                Math.min(ui.controller.currentPassword.length, 16)
            readonly property real glyphStep: 17

            Text {
                anchors.centerIn: parent
                text: "󰫣"
                color: "#58f8fafc"
                font.pixelSize: 15
                opacity: passwordGlyphs.glyphCount === 0 ? 1 : 0
                scale: passwordGlyphs.glyphCount === 0 ? 1 : 0.65

                Behavior on opacity { NumberAnimation { duration: 130 } }
                Behavior on scale {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }
            }

            Repeater {
                // Stable delegates avoid the one-frame flash caused by model
                // recreation when a password character is added or removed.
                model: 16

                delegate: Text {
                    required property int index
                    readonly property bool entered:
                        index < passwordGlyphs.glyphCount

                    width: 14
                    height: 20
                    text: "󰫣"
                    font.pixelSize: 13
                    color: "#f8fafc"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    x: passwordGlyphs.width / 2
                       + (index - (passwordGlyphs.glyphCount - 1) / 2)
                         * passwordGlyphs.glyphStep - width / 2
                    y: (passwordGlyphs.height - height) / 2
                    opacity: entered ? 1 : 0
                    scale: entered ? 1 : 0.55

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                    Behavior on scale {
                        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.IBeamCursor
            onClicked: passwordInput.forceActiveFocus()
        }
    }

    Item {
        id: dateBlock

        x: ui.clockContentX - width / 2
        y: hourText.y + hourText.height + 18
        width: 220
        height: 70

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(ui.now, "dd MMM yyyy").toUpperCase()
            color: "#bdf8fafc"
            font.family: "Audiowide"
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 3.5
        }

        Text {
            y: 26
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(ui.now, "dddd").toUpperCase()
            color: "#f8fafc"
            font.family: "Anurati"
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 5
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 52
        anchors.rightMargin: 84
        spacing: 54

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.osName.toUpperCase()
            color: "#76f8fafc"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 3
        }

        Text {
            id: rebootLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "REBOOT"
            color: rebootMouse.containsMouse ? "#f8fafc" : "#76f8fafc"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 3

            MouseArea {
                id: rebootMouse
                anchors.fill: parent
                anchors.margins: -14
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rebootProcess.running = true
            }
        }

        Text {
            id: shutdownLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "SHUTDOWN"
            color: shutdownMouse.containsMouse ? "#f8fafc" : "#76f8fafc"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 3

            MouseArea {
                id: shutdownMouse
                anchors.fill: parent
                anchors.margins: -14
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shutdownProcess.running = true
            }
        }
    }

    Item {
        id: profileRail

        width: Math.min(440, ui.width * 0.3)
        height: 150
        x: ui.width - width - 62
        y: ui.height * 0.42
        clip: true

        NumberAnimation {
            id: profileSlide
            target: ui.controller
            property: "carouselOffset"
            duration: 430
            easing.type: Easing.OutCubic
            onStopped: sideProfilesFadeOut.restart()
        }

        NumberAnimation {
            id: sideProfilesFadeOut
            target: ui.controller
            property: "sideProfilesOpacity"
            to: 0
            duration: 90
            onStopped: {
                ui.controller.completeProfileSelection();
                sideProfilesFadeIn.restart();
            }
        }

        NumberAnimation {
            id: sideProfilesFadeIn
            target: ui.controller
            property: "sideProfilesOpacity"
            to: 1
            duration: 170
            onStopped: ui.controller.carouselBusy = false
        }

        Repeater {
            model: ui.controller.profiles

            delegate: Item {
                id: profileDelegate

                required property var modelData
                required property int index
                readonly property bool active:
                    index === (ui.controller.carouselBusy
                               ? ui.controller.pendingProfileIndex
                               : ui.controller.selectedProfileIndex)

                width: 100
                height: 128
                x: profileRail.width / 2
                   + ui.controller.profileSlot(index) * ui.controller.profileSpacing
                   - ui.controller.carouselOffset - width / 2
                y: 0
                scale: active ? 1 : 0.73
                opacity: (active ? 1 : 0.42)
                         * (active ? 1 : ui.controller.sideProfilesOpacity)

                Behavior on scale {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 76
                    height: 76
                    radius: 38
                    color: "#5c101014"
                    border.width: profileDelegate.active ? 2 : 1
                    border.color: profileDelegate.active ? "#f8fafc" : "#4affffff"
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: ui.controller.profileHasPhoto(profileDelegate.modelData)
                                         ? 0 : 8
                        source: ui.controller.profileIcon(profileDelegate.modelData)
                        fillMode: ui.controller.profileHasPhoto(profileDelegate.modelData)
                                  ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        color: "#d8f8fafc"
                        font.pixelSize: 36
                        visible: ui.controller.profileIcon(profileDelegate.modelData) === ""
                    }
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 88
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: profileDelegate.modelData.name.toUpperCase()
                    color: profileDelegate.active ? "#f8fafc" : "#80f8fafc"
                    font.pixelSize: profileDelegate.active ? 11 : 9
                    font.bold: true
                    font.letterSpacing: 2
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !ui.controller.carouselBusy
                             && !ui.controller.authInProgress
                    cursorShape: profileDelegate.index === ui.controller.selectedProfileIndex
                                 ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: ui.controller.beginProfileSelection(
                                   profileDelegate.index, profileSlide)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: profileRail.horizontalCenter
        y: passwordPill.y + passwordPill.height + 14
        text: "󰫣"
        color: "#bdf8fafc"
        font.pixelSize: 17
        visible: ui.controller.selectedUser === ui.controller.sessionUser
    }

    Text {
        anchors.horizontalCenter: profileRail.horizontalCenter
        y: passwordPill.y + passwordPill.height + 42
        text: ui.controller.authInProgress ? "AUTHENTICATING" : "WAITING FOR KEY"
        color: "#68f8fafc"
        font.pixelSize: 9
        font.bold: true
        font.letterSpacing: 3.3
        visible: ui.controller.selectedUser === ui.controller.sessionUser
    }

    Rectangle {
        id: switchButton

        anchors.horizontalCenter: profileRail.horizontalCenter
        y: profileRail.y + 138
        width: 210
        height: 42
        radius: 21
        visible: ui.controller.selectedUser !== ui.controller.sessionUser
        color: switchMouse.containsMouse ? "#9918181d" : "#77101014"
        border.width: 1
        border.color: "#55ffffff"

        Text {
            anchors.centerIn: parent
            text: ui.controller.authInProgress
                  ? "OPENING SWITCHER"
                  : "SWITCH TO " + ui.controller.selectedProfile.name.toUpperCase()
            color: "#e8f8fafc"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.5
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            enabled: !ui.controller.authInProgress
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ui.controller.switchUser()
        }
    }

    Text {
        x: passwordPill.x
        y: passwordPill.y + passwordPill.height + 20
        text: ui.controller.selectedUser === ui.controller.sessionUser
              ? "AUTHENTICATION FAILED" : "UNABLE TO OPEN USER SWITCHER"
        color: Theme.danger
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 2
        opacity: ui.controller.authFailed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
