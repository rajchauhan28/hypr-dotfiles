//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick.Shapes
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    // Hyprland status
    readonly property int activeWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    property var wsWindows: ({})
    property var clients: []

    property bool powerExpanded: false
    property string armedPower: ""
    property real powerDrawerY: 500

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

    property bool bgDrawerOpen: false
    property real bgDrawerY: 300
    // Number of tray menus currently on screen. While any is open the drawer
    // must stay put: the menu is anchored to an icon inside it.
    property int trayMenusOpen: 0
    readonly property int trayItemCount: SystemTray.items.values.length
    readonly property int powerItemCount: 3
    readonly property real trayDrawerWidth: trayItemCount > 0
                                              ? (trayItemCount * Theme.iconSlot)
                                                + ((trayItemCount - 1) * 8) + 20
                                              : 140
    readonly property real powerDrawerWidth: (powerItemCount * Theme.iconSlot)
                                               + ((powerItemCount - 1) * 8) + 20

    Timer {
        id: bgDrawerHideTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.trayMenusOpen > 0) {
                restart();
                return;
            }
            root.bgDrawerOpen = false;
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

    // Window occupancy is polled; activeWs above updates immediately from
    // Hyprland's event socket when the focused workspace changes.
    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: clientsProc.running = true
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
        p.command = [Quickshell.env("HOME") + "/.config/quickshell/overview/hyprctl-compat.sh", cmd, arg];
        p.running = true;
    }

    function launchApp(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["sh", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"];
        p.running = true;
    }

    // The sidebar's pinned apps. The settings app writes this same file, so a
    // change there reaches the running bar without a restart. There is no
    // Config singleton in this config directory -- the bar owns the read.
    readonly property var sidebarPinnedDefaults: [
        { name: "Terminal", exec: "ghostty", "class": "com.mitchellh.ghostty", icon: "com.mitchellh.ghostty" },
        { name: "Brave", exec: "brave", "class": "brave-browser", icon: "brave-desktop" },
        { name: "Files", exec: "dolphin", "class": "org.kde.dolphin", icon: "org.kde.dolphin" },
        { name: "VS Code", exec: "code", "class": "code", icon: "vscode" }
    ]
    property var sidebarPinned: sidebarPinnedDefaults

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/leftbar/pinned.json"
        watchChanges: true
        onFileChanged: reload()
        // onLoaded only fires when the file exists; onLoadFailed is what covers
        // a deleted or unreadable file, and without it the bar would keep the
        // last list forever instead of falling back.
        onLoaded: {
            try {
                var d = JSON.parse(text());
                root.sidebarPinned = (d.pinned && d.pinned.length > 0)
                                       ? d.pinned : root.sidebarPinnedDefaults;
            } catch (e) {
                root.sidebarPinned = root.sidebarPinnedDefaults;
            }
        }
        onLoadFailed: root.sidebarPinned = root.sidebarPinnedDefaults
    }

    PanelWindow {
        id: barWindow
        anchors {
            left: true
            top: true
            bottom: true
        }
        implicitWidth: Theme.barWidth + Theme.cornerFillet
                       + Math.max(root.bgDrawerOpen ? root.trayDrawerWidth : 0,
                                  root.powerExpanded ? root.powerDrawerWidth : 0)
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "leftbar"
        WlrLayershell.exclusiveZone: Theme.barWidth

        // Wayland input region mask: expands to cover drawers when open
        mask: Region {
            item: (root.bgDrawerOpen || root.powerExpanded) ? fullMask : barMask
        }

        Item {
            id: barMask
            x: 0
            y: 0
            width: Theme.barWidth + Theme.cornerFillet
            height: barWindow.height
        }

        Item {
            id: fullMask
            x: 0
            y: 0
            width: barWindow.width
            height: barWindow.height
        }

        // Glassmorphic Left Panel Background (FIXED width Theme.barWidth + Theme.cornerFillet)
        Item {
            width: Theme.barWidth + Theme.cornerFillet
            height: parent.height

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                antialiasing: true

                ShapePath {
                    fillColor: Theme.panelBg
                    strokeColor: Theme.panelBorder
                    strokeWidth: 1

                    startX: 0
                    startY: 0

                    PathLine { x: Theme.barWidth + Theme.cornerFillet; y: 0 }
                    PathLine { x: Theme.barWidth + Theme.cornerFillet; y: Theme.edgeLine }

                    PathQuad {
                        x: Theme.barWidth
                        y: Theme.edgeLine + Theme.cornerFillet
                        controlX: Theme.barWidth
                        controlY: Theme.edgeLine
                    }

                    PathLine { x: Theme.barWidth; y: barWindow.height - Theme.edgeLine - Theme.cornerFillet }

                    PathQuad {
                        x: Theme.barWidth + Theme.cornerFillet
                        y: barWindow.height - Theme.edgeLine
                        controlX: Theme.barWidth
                        controlY: barWindow.height - Theme.edgeLine
                    }

                    PathLine { x: Theme.barWidth + Theme.cornerFillet; y: barWindow.height }
                    PathLine { x: 0; y: barWindow.height }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        // Horizontal Background Apps Drawer (System Tray)
        Rectangle {
            id: bgDrawer
            z: 10
            x: Theme.barWidth + 2
            y: root.bgDrawerY
            height: Theme.iconSlot + 14
            width: root.bgDrawerOpen ? root.trayDrawerWidth : 0
            opacity: root.bgDrawerOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            clip: true
            radius: Theme.radiusSmall + 4

            color: Theme.panelBg
            border.color: Theme.panelBorder
            border.width: 1

            Behavior on width {
                NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: bgDrawerHideTimer.stop()
                onExited: bgDrawerHideTimer.restart()
            }

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 8

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        implicitWidth: Theme.iconSlot
                        implicitHeight: Theme.iconSlot

                        QsMenuAnchor {
                            id: menuAnchor
                            menu: modelData.menu

                            // Without an anchor item the popup has no surface
                            // to parent to and open() silently does nothing —
                            // which is why right-click menus never appeared.
                            // The bar sits on the left edge, so hang the menu
                            // off the icon's right side.
                            anchor.item: bgAppBtn
                            anchor.edges: Edges.Right | Edges.Top
                            anchor.gravity: Edges.Right | Edges.Bottom

                            // The menu is its own surface, so opening it takes
                            // the pointer off the icon and the drawer's hide
                            // timer would collapse the anchor out from under
                            // the popup. Hold the drawer open while it lives.
                            onOpened: {
                                bgDrawerHideTimer.stop();
                                root.trayMenusOpen++;
                            }
                            onClosed: {
                                root.trayMenusOpen = Math.max(0, root.trayMenusOpen - 1);
                                bgDrawerHideTimer.restart();
                            }
                        }

                        Rectangle {
                            id: bgAppBtn
                            anchors.fill: parent
                            radius: Theme.radiusSmall
                            color: bgMouse.containsMouse ? Theme.cardHover : Theme.card
                            border.color: bgMouse.containsMouse ? Theme.accent : Theme.border
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            scale: bgMouse.containsPress ? 0.90 : (bgMouse.containsMouse ? 1.12 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                            Image {
                                id: bgIconImg
                                anchors.centerIn: parent
                                width: Math.round(Theme.iconSlot * 0.6)
                                height: width
                                source: modelData.icon || ""
                                sourceSize: Qt.size(64, 64)
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰖯"
                                font.pixelSize: 16
                                color: Theme.textSecondary
                                visible: bgIconImg.status !== Image.Ready
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 2
                                width: 4
                                height: 4
                                radius: 2
                                color: Theme.good
                            }
                        }

                        MouseArea {
                            id: bgMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                // onlyMenu items (nm-applet, blueman, …) expose
                                // no activate action at all, so a left click has
                                // to fall through to the menu or it does nothing.
                                var wantsMenu = mouse.button === Qt.RightButton
                                                || modelData.onlyMenu;

                                if (wantsMenu && modelData.hasMenu) {
                                    menuAnchor.open();
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate();
                                } else if (mouse.button === Qt.LeftButton) {
                                    modelData.activate();
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y !== 0)
                                    modelData.scroll(wheel.angleDelta.y, false);
                                if (wheel.angleDelta.x !== 0)
                                    modelData.scroll(wheel.angleDelta.x, true);
                            }
                            onContainsMouseChanged: {
                                if (containsMouse) bgDrawerHideTimer.stop();
                                root.setTooltip(containsMouse ? (modelData.title || "Tray Item") : "", bgMouse);
                            }
                        }
                    }
                }

                Text {
                    visible: root.trayItemCount === 0
                    text: "No system tray items"
                    font.pixelSize: 11
                    color: Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // Horizontal Power Options Drawer
        Rectangle {
            id: powerDrawer
            z: 10
            x: Theme.barWidth + 2
            y: root.powerDrawerY
            height: Theme.iconSlot + 14
            width: root.powerExpanded ? root.powerDrawerWidth : 0
            opacity: root.powerExpanded ? 1.0 : 0.0
            visible: opacity > 0.01
            clip: true
            radius: Theme.radiusSmall + 4

            color: Theme.panelBg
            border.color: Theme.panelBorder
            border.width: 1

            Behavior on width {
                NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animFast }
            }

            Timer {
                id: pwrArmTimer
                // Time the drawer stays up once you stop interacting with it.
                interval: 1500
                repeat: false
                onTriggered: {
                    root.powerExpanded = false;
                    root.armedPower = "";
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                // Stop, not restart: entering the drawer means you are aiming
                // for one of the buttons in it, so the countdown has to be held
                // rather than merely extended. Restarting here gave you a fixed
                // window from first hover to land the click no matter where the
                // cursor was -- survivable at 4s, but at 1.5s the drawer would
                // close out from under the pointer mid-reach.
                onEntered: pwrArmTimer.stop()
                onExited: pwrArmTimer.restart()
            }

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 8

                // 1. Lock Screen Button
                Item {
                    implicitWidth: Theme.iconSlot
                    implicitHeight: Theme.iconSlot

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: lockMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.color: lockMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1

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
                }

                // 2. Sleep / Suspend Button
                Item {
                    implicitWidth: Theme.iconSlot
                    implicitHeight: Theme.iconSlot

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: sleepMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.color: sleepMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1

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
                }

                // 3. Reboot Button
                Item {
                    implicitWidth: Theme.iconSlot
                    implicitHeight: Theme.iconSlot

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: rebMouse.containsMouse ? Theme.cardHover : Theme.card
                        border.color: rebMouse.containsMouse ? Theme.good : Theme.border
                        border.width: 1

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
                }
            }
        }

        // Inner Content Container (aligned inside Theme.barWidth)
        Item {
            x: 0
            y: Theme.edgeLine
            width: Theme.barWidth
            height: parent.height - (Theme.edgeLine * 2)

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: Theme.barPadding
                anchors.bottomMargin: Theme.barPadding
                spacing: 16

                // ---- 1. Dynamic Clock Island (Stacked HH / MM / AP) ----
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.max(34, Theme.barWidth - 12)
                    implicitHeight: 56
                    radius: Theme.radiusSmall
                    color: clockMouse.containsMouse ? Theme.cardHover : Theme.card
                    border.color: clockMouse.containsMouse ? Theme.borderStrong : Theme.border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    scale: clockMouse.containsPress ? 0.92 : (clockMouse.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            text: Qt.formatTime(root.now, "hh")
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrains Mono"
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: Qt.formatTime(root.now, "mm")
                            font.pixelSize: 12
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

                // ---- 3. Pinned Apps ----
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    // Pinned Sidebar Apps
                    Repeater {
                        model: root.sidebarPinned

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

                                Image {
                                    id: pinnedIconImg
                                    anchors.centerIn: parent
                                    width: Math.round(Theme.iconSlot * 0.6)
                                    height: width
                                    // There is no Config singleton here, so the
                                    // fallback is the class name and then the
                                    // glyph below -- not a theme-wide search.
                                    source: {
                                        var direct = Quickshell.iconPath(modelData.icon || "", true);
                                        if (direct !== "") return direct;
                                        return Quickshell.iconPath(modelData["class"] || "", true);
                                    }
                                    sourceSize: Qt.size(64, 64)
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰣆"
                                    font.pixelSize: 16
                                    color: Theme.textPrimary
                                    visible: pinnedIconImg.status !== Image.Ready
                                }
                            }

                            MouseArea {
                                id: appMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchApp(modelData.exec)
                                onContainsMouseChanged: root.setTooltip(containsMouse ? (modelData.name || modelData.exec) : "", appMouse)
                            }
                        }
                    }

                    // Separator at end of pinned apps
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Math.max(20, Theme.iconSlot - 10)
                        implicitHeight: 1
                        color: Theme.border
                    }
                }

                // Flexible spacer pushing bottom controls down
                Item {
                    Layout.fillHeight: true
                }

                // ---- 4. Bottom Controls (Background Apps Drawer Arrow, Overview & Power Button) ----
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    // > (Chevron Arrow) Button for Background Apps Drawer (Shifted ABOVE Overview)
                    Rectangle {
                        id: chevronBtn
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Theme.iconSlot
                        implicitHeight: Theme.iconSlot
                        radius: Theme.radiusSmall
                        color: (root.bgDrawerOpen || chevronMouse.containsMouse) ? Theme.cardHover : Theme.card
                        border.color: (root.bgDrawerOpen || chevronMouse.containsMouse) ? Theme.accent : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        scale: chevronMouse.containsPress ? 0.90 : (chevronMouse.containsMouse ? 1.12 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: root.bgDrawerOpen ? "󰅁" : "󰅂"
                            font.pixelSize: 16
                            color: (root.bgDrawerOpen || chevronMouse.containsMouse) ? Theme.textPrimary : Theme.textMuted
                        }

                        MouseArea {
                            id: chevronMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pt = mapToItem(null, 0, height / 2);
                                root.bgDrawerY = pt.y - (Theme.iconSlot + 14) / 2;
                                root.bgDrawerOpen = !root.bgDrawerOpen;
                                if (root.bgDrawerOpen) bgDrawerHideTimer.stop();
                            }
                            onContainsMouseChanged: {
                                if (containsMouse) {
                                    var pt = mapToItem(null, 0, height / 2);
                                    root.bgDrawerY = pt.y - (Theme.iconSlot + 14) / 2;
                                    root.bgDrawerOpen = true;
                                    bgDrawerHideTimer.stop();
                                    root.setTooltip("Background Apps (Drawer)", chevronMouse);
                                } else {
                                    bgDrawerHideTimer.restart();
                                    root.setTooltip("", chevronMouse);
                                }
                            }
                        }
                    }

                    // Overview Toggle Pill (Tiles Button -> Super+Tab Workspace & Window Overview)
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
                            onClicked: root.launchApp(Quickshell.env("HOME") + "/.config/hypr/toggle_overview.sh")
                            onContainsMouseChanged: root.setTooltip(containsMouse ? "Overview (Super+Tab)" : "", ovMouse)
                        }
                    }

                    // Main Power Button
                    Rectangle {
                        id: mainPwrBtn
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Theme.iconSlot
                        implicitHeight: Theme.iconSlot
                        radius: Theme.radiusSmall
                        color: (root.armedPower === "shutdown" || pwrMouse.containsMouse || root.powerExpanded)
                               ? Qt.rgba(0.93, 0.26, 0.26, 0.25) : Theme.card
                        border.color: (root.armedPower === "shutdown" || pwrMouse.containsMouse || root.powerExpanded)
                                      ? Theme.danger : Theme.border
                        border.width: (root.armedPower === "shutdown" || root.powerExpanded) ? 2 : 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        scale: pwrMouse.containsPress ? 0.90 : (pwrMouse.containsMouse ? 1.12 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰐥"
                            font.pixelSize: 16
                            color: (root.armedPower === "shutdown" || pwrMouse.containsMouse || root.powerExpanded) ? Theme.danger : Theme.textSecondary
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        MouseArea {
                            id: pwrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var pt = mapToItem(null, 0, height / 2);
                                root.powerDrawerY = pt.y - (Theme.iconSlot + 14) / 2;
                                root.powerExpanded = !root.powerExpanded;
                                if (root.powerExpanded) {
                                    root.armedPower = "shutdown";
                                    pwrArmTimer.restart();
                                } else {
                                    root.armedPower = "";
                                }
                            }
                            onContainsMouseChanged: {
                                if (containsMouse) {
                                    var pt = mapToItem(null, 0, height / 2);
                                    root.powerDrawerY = pt.y - (Theme.iconSlot + 14) / 2;
                                    root.powerExpanded = true;
                                    root.armedPower = "shutdown";
                                    pwrArmTimer.restart();
                                    root.setTooltip("Power Options", pwrMouse);
                                } else {
                                    root.setTooltip("", pwrMouse);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Floating Side Tooltip Label Pill
        Rectangle {
            x: Theme.barWidth + 10
            y: Math.max(10, root.tooltipY - height / 2)
            visible: root.activeTooltip !== "" && !root.bgDrawerOpen && !root.powerExpanded
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on y { NumberAnimation { duration: 150; easing.type: Theme.easeOutQuint } }

            implicitWidth: tooltipLabel.implicitWidth + 20
            implicitHeight: 26
            radius: 6
            color: "#f2121218"
            border.color: Theme.panelBorder
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
}
