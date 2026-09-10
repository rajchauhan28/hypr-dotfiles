import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The popup shell that replaced swaync. Every knob here is read live by
// notifications/Theme.qml, so a drag reshapes the card already on screen.
ColumnLayout {
    id: page

    spacing: Theme.gap

    // ---- Critical keyword list ----------------------------------------
    // Config.set replaces the whole array; there is no per-element write, so
    // both helpers copy, edit, and put the copy back.
    function addKeyword(raw) {
        var word = String(raw).trim().toLowerCase();
        if (word === "")
            return;
        var list = (Config.get("notifications", "criticalKeywords") || []).slice();
        for (var i = 0; i < list.length; i++)
            if (String(list[i]).toLowerCase() === word)
                return;
        list.push(word);
        Config.set("notifications", "criticalKeywords", list);
    }

    function removeKeyword(index) {
        var list = (Config.get("notifications", "criticalKeywords") || []).slice();
        if (index < 0 || index >= list.length)
            return;
        list.splice(index, 1);
        Config.set("notifications", "criticalKeywords", list);
    }

    Card {
        title: "POPUP SHAPE"
        subtitle: "One card welded to the right screen edge"
        section: "notifications"
        keys: ["panelWidth", "bottomMargin", "radiusPanel", "cornerFillet"]

        SliderRow { section: "notifications"; key: "panelWidth"; label: "Card width"; from: 260; to: 560; step: 4; suffix: " px" }
        SliderRow { section: "notifications"; key: "bottomMargin"; label: "Distance from bottom"; from: 0; to: 160; suffix: " px" }
        SliderRow { section: "notifications"; key: "radiusPanel"; label: "Corner radius"; from: 0; to: 36; suffix: " px" }
        SliderRow { section: "notifications"; key: "cornerFillet"; label: "Edge fillet"; from: 0; to: 48; suffix: " px" }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: Config.get("notifications", "bottomMargin")
                     < Config.get("notifications", "cornerFillet")
            text: "Distance from bottom is below the fillet size, so the shell clamps it — "
                  + "the bottom scoop is drawn below the card and would otherwise clip flat."
            font.pixelSize: 9
            lineHeight: 1.35
            color: Theme.warn
            wrapMode: Text.WordWrap
        }
    }

    Card {
        title: "CONTENT"
        subtitle: "Inside one entry"
        section: "notifications"
        keys: ["cardPadding", "iconSize", "radiusSmall", "bodyMaxLines"]

        SliderRow { section: "notifications"; key: "cardPadding"; label: "Padding"; from: 4; to: 28; suffix: " px" }
        SliderRow { section: "notifications"; key: "iconSize"; label: "App icon size"; from: 16; to: 64; suffix: " px" }
        SliderRow { section: "notifications"; key: "radiusSmall"; label: "Icon / button radius"; from: 0; to: 20; suffix: " px" }
        SliderRow { section: "notifications"; key: "bodyMaxLines"; label: "Body lines"; from: 1; to: 12 }
    }

    Card {
        title: "BEHAVIOUR"
        subtitle: "Critical notifications never time out"
        section: "notifications"
        keys: ["maxVisible", "timeoutLow", "timeoutNormal"]

        SliderRow { section: "notifications"; key: "maxVisible"; label: "Max on screen"; from: 1; to: 10 }
        SliderRow { section: "notifications"; key: "timeoutNormal"; label: "Normal timeout"; from: 1; to: 30; suffix: " s" }
        SliderRow { section: "notifications"; key: "timeoutLow"; label: "Low timeout"; from: 1; to: 30; suffix: " s" }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: "An app that asks for its own timeout gets it; these apply when it doesn't."
            font.pixelSize: 9
            color: Theme.textFaint
            wrapMode: Text.WordWrap
        }
    }

    Card {
        title: "ALWAYS CRITICAL"
        subtitle: "Words that pin a notification until you dismiss it"
        section: "notifications"
        keys: ["timeoutCritical", "criticalKeywords"]

        SliderRow {
            section: "notifications"
            key: "timeoutCritical"
            label: "App-declared critical stays for"
            from: 0
            to: 120
            step: 5
            suffix: " s"
            zeroLabel: "never expires"
        }

        Text {
            Layout.fillWidth: true
            text: "Wifi, bluetooth and browser chat notifications mark themselves critical "
                  + "for routine messages, which is why they used to sit there until clicked. "
                  + "The words below override that in the other direction — anything matching "
                  + "one stays until you dismiss it, whatever the app asked for."
            font.pixelSize: 9
            lineHeight: 1.35
            color: Theme.textFaint
            wrapMode: Text.WordWrap
        }

        // Matching is a case-insensitive substring test against the app name,
        // the summary and the body, so "reboot" also catches "Reboot required".
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            Repeater {
                model: Config.get("notifications", "criticalKeywords")

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: chipRow.implicitWidth + 16
                    height: 24
                    radius: Theme.radiusSmall
                    color: chipMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                    border.color: chipMouse.containsMouse ? Theme.danger : Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: modelData
                            font.pixelSize: 10
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "\u2715"
                            font.pixelSize: 9
                            color: chipMouse.containsMouse ? Theme.danger : Theme.textFaint
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.removeKeyword(index)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radiusSmall
            color: Theme.cardAlt
            border.color: keywordInput.activeFocus ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                TextInput {
                    id: keywordInput
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    color: Theme.textPrimary
                    selectByMouse: true
                    clip: true
                    onAccepted: {
                        page.addKeyword(keywordInput.text);
                        keywordInput.text = "";
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Add a word or phrase, then press Enter…"
                        font: keywordInput.font
                        color: Theme.textFaint
                        visible: keywordInput.text === ""
                    }
                }

                Text {
                    text: "Enter"
                    font.pixelSize: 9
                    color: Theme.textFaint
                    visible: keywordInput.text !== ""
                }
            }
        }
    }

    Card {
        title: "TEST"
        subtitle: "Send a notification through the running shell"

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "Normal", urgency: "normal" },
                    { label: "Low", urgency: "low" },
                    { label: "Critical", urgency: "critical" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    implicitWidth: 92
                    implicitHeight: 28
                    radius: Theme.radiusSmall
                    color: sendMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                    border.color: Theme.border
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 11
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([
                            "notify-send",
                            "-u", modelData.urgency,
                            "-a", "Shell Settings",
                            modelData.label + " notification",
                            "This is what a " + modelData.urgency
                              + " notification looks like with the current settings."
                        ])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 92
                implicitHeight: 28
                radius: Theme.radiusSmall
                color: clearMouse.containsMouse ? Theme.cardHover : "transparent"
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Dismiss all"
                    font.pixelSize: 11
                    color: clearMouse.containsMouse ? Theme.danger : Theme.textMuted
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([
                        "qs", "ipc", "call", "notifications", "dismissAll"
                    ])
                }
            }
        }
    }
}
