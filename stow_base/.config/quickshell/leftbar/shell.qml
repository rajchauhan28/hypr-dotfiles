import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Shapes

ShellRoot {
    id: root

    // Hyprland status
    property int activeWs: 1
    property var wsWindows: ({})
    property var clients: []

    property bool powerExpanded: false
    property string armedPower: ""

    property bool clockPopupOpen: false
    property int clockPopupX: 70
    property int clockPopupY: 20

    property string activeTooltip: ""
    property real tooltipY: 0

    function setTooltip(text, item) {
        if (text && item) {
            var pt = item.mapToItem(null, 0, item.height / 2);
            root.tooltipY = pt.y;
            root.activeTooltip = text;
        } else {
            root.activeTooltip = "";
        }
    }

    property date now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Poll active workspace & clients
    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            activeWsProc.running = true;
            clientsProc.running = true;
        }
    }

    Process {
        id: activeWsProc
        command: ["bash", "-c", "hyprctl -j activeworkspace | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var p = JSON.parse(data.trim());
                    root.activeWs = p.id || 1;
                } catch (e) {}
            }
        }
    }

    Process {
        id: clientsProc
        command: ["bash", "-c", "hyprctl -j clients | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var cls = JSON.parse(data.trim());
                    root.clients = cls;
                    var map = {};
                    for (var i = 0; i < cls.length; i++) {
                        var w = cls[i];
                        if (w && w.workspace && w.workspace.id) {
                            map[w.workspace.id] = true;
                        }
                    }
                    root.wsWindows = map;
                } catch (e) {}
            }
        }
    }

    function dispatchHypr(cmd, arg) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["/home/reign/.config/quickshell/overview/hyprctl-compat.sh", cmd, arg];
        p.running = true;
    }

    function launchApp(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["sh", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"];
        p.running = true;
    }

    PanelWindow {
        id: barWindow
        anchors {
            left: true
            top: true
            bottom: true
        }
        implicitWidth: Theme.barWidth
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "leftbar"
        WlrLayershell.exclusiveZone: Theme.barWidth

        // Glassmorphic Left Panel Background
        Rectangle {
            anchors.fill: parent
            color: Theme.panelBg
            border.color: Theme.panelBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Theme.barPadding
                anchors.bottomMargin: Theme.barPadding
                spacing: 16

                // ---- 1. Dynamic Clock Island (Stacked HH / MM) ----
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(34, Theme.barWidth - 12)
                    implicitHeight: 52
                    radius: Theme.radiusSmall
                    color: clockMouse.containsMouse ? Theme.cardHover : Theme.card
                    border.color: clockMouse.containsMouse ? Theme.borderStrong : Theme.border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    scale: clockMouse.containsPress ? 0.92 : (clockMouse.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -3

                        Text {
                            text: Qt.formatTime(root.now, "hh")
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "JetBrains Mono"
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: Qt.formatTime(root.now, "mm")
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "JetBrains Mono"
                            color: Theme.accent
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: Qt.formatTime(root.now, "AP")
                            font.pixelSize: 8
                            font.bold: true
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clockPopupOpen = !root.clockPopupOpen
                    }
                }

                // ---- 2. Vertical Workspaces Switcher ----
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.iconSlot
                    implicitHeight: 5 * 34

                    // Sliding active workspace highlight capsule
                    Rectangle {
                        width: Theme.iconSlot - 4
                        height: 30
                        radius: Theme.radiusSmall
                        color: Theme.accent
                        opacity: 0.25
                        border.color: Theme.accent
                        border.width: 1
                        x: 2
                        y: Math.max(0, Math.min(4, root.activeWs - 1)) * 34 + 2

                        Behavior on y {
                            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint }
                        }
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 4

                        Repeater {
                            model: 5
                            delegate: Item {
                                readonly property int wsNum: index + 1
                                width: Theme.iconSlot
                                height: 30

                                Rectangle {
                                    id: wsItemBg
                                    anchors.centerIn: parent
                                    width: Theme.iconSlot - 6
                                    height: 28
                                    radius: Theme.radiusSmall - 2
                                    color: wsMouse.containsMouse ? Theme.cardHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    scale: wsMouse.containsPress ? 0.90 : (wsMouse.containsMouse ? 1.08 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsNum
                                        font.pixelSize: 12
                                        font.bold: root.activeWs === wsNum
                                        color: root.activeWs === wsNum ? Theme.textPrimary : Theme.textMuted
                                    }

                                    // Window indicator dot
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottomMargin: 2
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: Theme.good
                                        visible: !!root.wsWindows[wsNum] && root.activeWs !== wsNum
                                    }
                                }

                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.dispatchHypr("workspace", String(wsNum))
                                }
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(20, Theme.iconSlot - 10)
                    implicitHeight: 1
                    color: Theme.border
                }

                // ---- 3. Background / Taskbar App Quick Launchers ----
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Repeater {
                        model: [
                            { name: "Terminal", icon: "󰆍", exec: "kitty" },
                            { name: "Browser", icon: "󰈹", exec: "zen-browser || firefox" },
                            { name: "Files", icon: "󰉋", exec: "nemo || thunar" },
                            { name: "Code", icon: "󰨞", exec: "code || vscodium" }
                        ]

                        delegate: Item {
                            implicitWidth: Theme.iconSlot
                            implicitHeight: Theme.iconSlot
                            Layout.alignment: Qt.AlignHCenter

                            Rectangle {
                                id: appBtn
                                anchors.fill: parent
                                radius: Theme.radiusSmall
                                color: appMouse.containsMouse ? Theme.cardHover : Theme.card
                                border.color: appMouse.containsMouse ? Theme.borderStrong : Theme.border
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                scale: appMouse.containsPress ? 0.90 : (appMouse.containsMouse ? 1.12 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    color: Theme.textPrimary
                                }
                            }

                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchApp(modelData.exec)
                            }
                        }
                    }
                }

                // Flexible spacer pushing bottom controls down
                Item {
                    Layout.fillHeight: true
                }

                // ---- 4. Bottom Controls (Overview & Expanding Power Slider) ----
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    // Overview Toggle Pill (Tiles Button -> Super+Tab Overview)
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Theme.iconSlot
                        implicitHeight: Theme.iconSlot
                        radius: Theme.radiusSmall
                        color: ovMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.color: ovMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        scale: ovMouse.containsPress ? 0.90 : (ovMouse.containsMouse ? 1.12 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰕮"
                            font.pixelSize: 16
                            color: ovMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: ovMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp("/home/reign/.config/hypr/toggle_overview.sh")
                            onContainsMouseChanged: root.setTooltip(containsMouse ? "Overview (Super+Tab)" : "", ovMouse)
                        }
                    }

                    // Sliding Expanding Power Slider
                    Item {
                        id: powerSlider
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 46
                        implicitHeight: root.powerExpanded ? 176 : 38
                        clip: false

                        Behavior on implicitHeight {
                            NumberAnimation { duration: 320; easing.type: Theme.easeOutExpo }
                        }

                        Timer {
                            id: pwrArmTimer
                            interval: 4000
                            repeat: false
                            onTriggered: {
                                root.powerExpanded = false;
                                root.armedPower = "";
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            // Exposed Action Buttons (appear when expanded)
                            // 1. Lock Screen
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Theme.iconSlot
                                implicitHeight: Theme.iconSlot
                                radius: Theme.radiusSmall
                                opacity: root.powerExpanded ? 1 : 0
                                visible: opacity > 0
                                color: lockMouse.containsMouse ? Theme.cardHover : Theme.card
                                border.color: lockMouse.containsMouse ? Theme.accent : Theme.border
                                border.width: 1

                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                scale: lockMouse.containsPress ? 0.90 : (lockMouse.containsMouse ? 1.12 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌾"
                                    font.pixelSize: 16
                                    color: Theme.textPrimary
                                }

                                MouseArea {
                                    id: lockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerExpanded = false;
                                        root.launchApp("hyprlock");
                                    }
                                    onContainsMouseChanged: root.setTooltip(containsMouse ? "Lock Screen" : "", lockMouse)
                                }
                            }

                            // 2. Sleep / Suspend
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Theme.iconSlot
                                implicitHeight: Theme.iconSlot
                                radius: Theme.radiusSmall
                                opacity: root.powerExpanded ? 1 : 0
                                visible: opacity > 0
                                color: sleepMouse.containsMouse ? Theme.cardHover : Theme.card
                                border.color: sleepMouse.containsMouse ? Theme.accent : Theme.border
                                border.width: 1

                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                scale: sleepMouse.containsPress ? 0.90 : (sleepMouse.containsMouse ? 1.12 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰤄"
                                    font.pixelSize: 16
                                    color: Theme.textPrimary
                                }

                                MouseArea {
                                    id: sleepMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerExpanded = false;
                                        root.launchApp("systemctl suspend");
                                    }
                                    onContainsMouseChanged: root.setTooltip(containsMouse ? "Sleep / Suspend" : "", sleepMouse)
                                }
                            }

                            // 3. Reboot
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Theme.iconSlot
                                implicitHeight: Theme.iconSlot
                                radius: Theme.radiusSmall
                                opacity: root.powerExpanded ? 1 : 0
                                visible: opacity > 0
                                color: rebMouse.containsMouse ? Theme.cardHover : Theme.card
                                border.color: rebMouse.containsMouse ? Theme.good : Theme.border
                                border.width: 1

                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                scale: rebMouse.containsPress ? 0.90 : (rebMouse.containsMouse ? 1.12 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰜉"
                                    font.pixelSize: 16
                                    color: rebMouse.containsMouse ? Theme.good : Theme.textPrimary
                                }

                                MouseArea {
                                    id: rebMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerExpanded = false;
                                        root.launchApp("systemctl reboot");
                                    }
                                    onContainsMouseChanged: root.setTooltip(containsMouse ? "Reboot PC" : "", rebMouse)
                                }
                            }

                            // Main Power Button (stays at bottom in exact same position)
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Theme.iconSlot
                                implicitHeight: Theme.iconSlot
                                radius: Theme.radiusSmall
                                color: (root.armedPower === "shutdown" || pwrMouse.containsMouse) 
                                       ? Qt.rgba(0.93, 0.26, 0.26, 0.25) : Theme.card
                                border.color: (root.armedPower === "shutdown" || pwrMouse.containsMouse) 
                                              ? Theme.danger : Theme.border
                                border.width: root.armedPower === "shutdown" ? 2 : 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                                scale: pwrMouse.containsPress ? 0.90 : (pwrMouse.containsMouse ? 1.12 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰐥"
                                    font.pixelSize: 16
                                    color: (root.armedPower === "shutdown" || pwrMouse.containsMouse) ? Theme.danger : Theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                MouseArea {
                                    id: pwrMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.powerExpanded) {
                                            // First click: expand slider and arm shutdown
                                            root.powerExpanded = true;
                                            root.armedPower = "shutdown";
                                            pwrArmTimer.restart();
                                        } else if (root.armedPower === "shutdown") {
                                            // Second click: trigger shutdown
                                            root.powerExpanded = false;
                                            root.armedPower = "";
                                            pwrArmTimer.stop();
                                            root.launchApp("systemctl poweroff");
                                        } else {
                                            root.powerExpanded = false;
                                            root.armedPower = "";
                                        }
                                    }
                                    onContainsMouseChanged: root.setTooltip(containsMouse ? (root.armedPower === "shutdown" ? "Click to Shutdown" : "Power Options") : "", pwrMouse)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Floating Side Tooltip Label Pill
        Rectangle {
            x: Theme.barWidth + 6
            y: Math.max(10, root.tooltipY - height / 2)
            visible: root.activeTooltip !== ""
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on y { NumberAnimation { duration: 150; easing.type: Theme.easeOutQuint } }

            implicitWidth: tooltipLabel.implicitWidth + 20
            implicitHeight: 28
            radius: 8
            color: "#f2121218"
            border.color: "#30ffffff"
            border.width: 1

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: root.activeTooltip
                font.pixelSize: 11
                font.bold: true
                color: Theme.textPrimary
            }
        }
    }

    // ---- 5. Floating Draggable Always-On-Top Clock Widget ----
    PanelWindow {
        id: clockPopupWin
        visible: root.clockPopupOpen
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "leftbar-clock-popup"

        anchors {
            left: true
            top: true
            right: true
            bottom: true
        }

        // Pass-through clicks outside the card so rest of screen is clickable
        mask: Region {
            item: popupCard
        }

        Rectangle {
            id: popupCard
            x: root.clockPopupX
            y: root.clockPopupY
            width: 320
            height: 180
            radius: 18
            color: "#f4101015"
            border.color: "#30ffffff"
            border.width: 1

            // Hardware-accelerated smooth QML dragging with zero Wayland relayout jitter
            MouseArea {
                id: popupDragArea
                anchors.fill: parent
                drag.target: popupCard
                drag.minimumX: 10
                drag.minimumY: 10
                drag.maximumX: Math.max(100, clockPopupWin.width - popupCard.width - 10)
                drag.maximumY: Math.max(100, clockPopupWin.height - popupCard.height - 10)
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onReleased: {
                    root.clockPopupX = popupCard.x;
                    root.clockPopupY = popupCard.y;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header bar with Close Button
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "󰥔 DIGITAL CLOCK"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: 13
                        color: closeMouse.containsMouse ? Qt.rgba(0.93, 0.26, 0.26, 0.3) : Theme.card
                        border.color: closeMouse.containsMouse ? Theme.danger : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.pixelSize: 12
                            color: closeMouse.containsMouse ? Theme.danger : Theme.textSecondary
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clockPopupOpen = false
                        }
                    }
                }

                // Clock Display (Hours:Minutes:Seconds + Date)
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: Qt.formatTime(root.now, "hh:mm:ss AP")
                        font.pixelSize: 28
                        font.bold: true
                        font.family: "JetBrains Mono"
                        font.letterSpacing: 1.2
                        color: Theme.textPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.accent
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Always On Top Status Pill
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 150
                    implicitHeight: 22
                    radius: 11
                    color: "#181822"
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰸗 Draggable Always-On-Top"
                        font.pixelSize: 9
                        color: Theme.textMuted
                    }
                }
            }
        }
    }
}
