import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Rectangle {
    id: wsCard

    property var workspaceId: 1
    property string workspaceName: "1"
    property var windows: []
    property bool isActive: false
    property bool isDropTarget: false

    // Top-level Item a dragged window card is reparented into, so it escapes
    // this card's bounds and the ScrollView's clip rect while being dragged.
    property Item dragOverlay: null

    signal workspaceSelected(var id)
    signal windowFocusRequested(string address)
    signal windowCloseRequested(string address)
    signal windowDrop(string address)
    signal dragStarted()
    signal dragEnded()

    implicitWidth: 200
    implicitHeight: 180
    radius: 16
    color: wsCard.isDropTarget ? "#2a2a35" : (wsCard.isActive ? "#22222c" : (cardMouse.containsMouse ? "#1c1c24" : "#121216"))
    border.color: wsCard.isDropTarget ? "#80ffffff" : (wsCard.isActive ? "#50ffffff" : (cardMouse.containsMouse ? "#30ffffff" : "#14ffffff"))
    border.width: wsCard.isActive || wsCard.isDropTarget ? 2 : 1

    scale: cardMouse.pressed ? 0.98 : (cardMouse.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        SpringAnimation {
            spring: 4.8
            damping: 0.55
            epsilon: 0.005
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    function getAppIconName(appClass) {
        var cls = (appClass || "").toLowerCase();
        var name = "";
        if (cls.indexOf("brave") !== -1) name = "brave-desktop";
        else if (cls.indexOf("ghostty") !== -1) name = "com.mitchellh.ghostty";
        else if (cls.indexOf("code") !== -1 || cls.indexOf("vsc") !== -1) name = "code";
        else if (cls.indexOf("discord") !== -1 || cls.indexOf("webcord") !== -1) name = "discord";
        else if (cls.indexOf("alacritty") !== -1) name = "alacritty";
        else if (cls.indexOf("kitty") !== -1) name = "kitty";
        else if (cls.indexOf("firefox") !== -1) name = "firefox";
        else if (cls.indexOf("spotify") !== -1) name = "spotify";
        else if (cls.indexOf("thunar") !== -1) name = "org.xfce.thunar";
        else if (cls.indexOf("dolphin") !== -1) name = "org.kde.dolphin";
        else if (cls.indexOf("rdp") !== -1) name = "org.remmina.Remmina";
        else name = cls;

        if (name && Quickshell.iconPath(name, true) !== "") return name;
        if (typeof Config !== "undefined" && Config.getAvailableIcon) {
            return Config.getAvailableIcon(name, appClass, appClass);
        }
        return name;
    }

    function getAppIconFallback(appClass) {
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

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["window"]

        function canAcceptDrop(source) {
            if (!source)
                return false;
            // Dropping onto the workspace the window already lives on is a no-op.
            if (source.sourceWorkspaceId === wsCard.workspaceId)
                return false;
            if (wsCard.workspaceId === "special:S-term") {
                var d = source.windowData;
                var cls = (d && d.class) ? d.class.toLowerCase() : "";
                if (cls !== "com.mitchellh.ghostty")
                    return false;
            }
            return true;
        }

        onEntered: drag => {
            if (!canAcceptDrop(drag.source)) {
                drag.accepted = false;
                return;
            }
            drag.accept();
            wsCard.isDropTarget = true;
        }

        onPositionChanged: drag => {
            if (!canAcceptDrop(drag.source))
                drag.accepted = false;
        }

        onExited: wsCard.isDropTarget = false

        onDropped: drag => {
            wsCard.isDropTarget = false;
            if (!canAcceptDrop(drag.source)) {
                drag.accepted = false;
                return;
            }
            var winAddress = drag.source.windowAddress || "";
            if (winAddress) {
                drag.accept();
                wsCard.windowDrop(winAddress);
            }
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            wsCard.workspaceSelected(wsCard.workspaceId);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Header badge
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: Math.max(26, nameText.implicitWidth + 12)
                    implicitHeight: 26
                    radius: 8
                    color: wsCard.isActive ? "#25ffffff" : "#10ffffff"

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        text: wsCard.workspaceName
                        font.pixelSize: 12
                        font.bold: true
                        color: wsCard.isActive ? "#ffffff" : "#e4e4e7"
                    }
                }

                Text {
                    text: (wsCard.windows || []).length > 0 ? ((wsCard.windows || []).length + " window" + ((wsCard.windows || []).length > 1 ? "s" : "")) : "Empty"
                    font.pixelSize: 11
                    color: (wsCard.windows || []).length > 0 ? "#a1a1aa" : "#71717a"
                    Layout.fillWidth: true
                }
            }

            // Spatial Mini-map of windows inside workspace
            Item {
                id: spatialView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false

                Repeater {
                    model: wsCard.windows || []
                    delegate: Rectangle {
                        id: winRect
                        property real scaleX: spatialView.width / 1920.0
                        property real scaleY: spatialView.height / 1200.0
                        property bool isDragging: winMouse.drag.active

                        // Calculate spatial position based on Hyprland 'at' and 'size' coordinates
                        // Use modulo 1920 and 1200 to normalize multi-monitor absolute coordinates
                        property real localX: {
                            var rawX = modelData.at ? modelData.at[0] : 0;
                            return ((rawX % 1920) + 1920) % 1920;
                        }
                        property real localY: {
                            var rawY = modelData.at ? modelData.at[1] : 0;
                            return ((rawY % 1200) + 1200) % 1200;
                        }

                        x: localX * scaleX
                        y: localY * scaleY
                        width: Math.max((modelData.size ? modelData.size[0] : 0) * scaleX, 10)
                        height: Math.max((modelData.size ? modelData.size[1] : 0) * scaleY, 10)

                        color: isDragging ? "#303040" : (winMouse.containsMouse ? "#282836" : "#1a1a22")
                        border.color: isDragging ? "#60ffffff" : (winMouse.containsMouse ? "#40ffffff" : "#12ffffff")
                        border.width: isDragging ? 2 : 1
                        radius: 6

                        z: winMouse.drag.active ? 100 : 1
                        scale: winMouse.drag.active ? 1.3 : (winMouse.containsMouse ? 1.05 : 1.0)
                        opacity: winMouse.drag.active ? 0.8 : 1.0

                        Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.55 } }
                        Behavior on x { enabled: !winMouse.drag.active; SpringAnimation { spring: 4.0; damping: 0.50 } }
                        Behavior on y { enabled: !winMouse.drag.active; SpringAnimation { spring: 4.0; damping: 0.50 } }

                        property string windowAddress: modelData.address
                        property var windowData: modelData
                        property var sourceWorkspaceId: wsCard.workspaceId

                        Drag.active: winMouse.drag.active
                        Drag.source: winRect
                        Drag.keys: ["window"]
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        // Move into the shared overlay for the duration of the
                        // drag, then back into the mini-map with its position
                        // bindings restored (dragging breaks them).
                        function beginDrag() {
                            if (!wsCard.dragOverlay || parent === wsCard.dragOverlay)
                                return;
                            var p = spatialView.mapToItem(wsCard.dragOverlay, x, y);
                            parent = wsCard.dragOverlay;
                            x = p.x;
                            y = p.y;
                        }

                        function endDrag() {
                            if (parent !== spatialView)
                                parent = spatialView;
                            x = Qt.binding(function () { return winRect.localX * winRect.scaleX; });
                            y = Qt.binding(function () { return winRect.localY * winRect.scaleY; });
                        }

                        Image {
                            id: appIcon
                            anchors.centerIn: parent
                            width: Math.max(Math.min(parent.width, parent.height) * 0.5, 16)
                            height: width
                            // Checked lookup: an unknown class yields "" so the
                            // emoji fallback shows, instead of the icon
                            // provider's magenta missing-image checkerboard
                            // (which counts as Image.Ready and hides it).
                            source: Quickshell.iconPath(wsCard.getAppIconName(modelData.class), true)
                            visible: parent.width >= 16 && parent.height >= 16 && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: wsCard.getAppIconFallback(modelData.class)
                            color: "white"
                            font.pixelSize: Math.max(Math.min(parent.width, parent.height) * 0.5, 10)
                            visible: parent.width >= 16 && parent.height >= 16 && appIcon.status !== Image.Ready
                        }

                        MouseArea {
                            id: winMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: winRect
                            drag.threshold: 6
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                            // A release that ended a drag must not also count as
                            // a click, otherwise every drag focused the window
                            // and closed the overview before the drop landed.
                            property bool didDrag: false

                            onPressed: mouse => {
                                didDrag = false;
                            }

                            onPositionChanged: mouse => {
                                if (drag.active && !didDrag) {
                                    didDrag = true;
                                    winRect.beginDrag();
                                    wsCard.dragStarted();
                                }
                            }

                            onReleased: mouse => {
                                if (didDrag) {
                                    winRect.Drag.drop();
                                    winRect.endDrag();
                                    wsCard.dragEnded();
                                }
                            }

                            onCanceled: {
                                if (didDrag) {
                                    winRect.Drag.cancel();
                                    winRect.endDrag();
                                    wsCard.dragEnded();
                                    didDrag = false;
                                }
                            }

                            onClicked: mouse => {
                                if (didDrag)
                                    return;
                                if (mouse.button === Qt.MiddleButton) {
                                    wsCard.windowCloseRequested(modelData.address);
                                } else {
                                    wsCard.windowFocusRequested(modelData.address);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: (wsCard.windows || []).length === 0
                    text: "Workspace " + wsCard.workspaceName
                    font.pixelSize: 14
                    font.bold: true
                    color: "#08ffffff"
                }
            }
        }
    }
}
