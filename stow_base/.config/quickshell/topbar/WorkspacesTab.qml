import QtQuick
import QtQuick.Layouts

Item {
    id: tab

    property var clients: []
    property int activeWs: 1
    property int screenW: 1920
    property int screenH: 1200
    // 0 = nothing hovered, so the detail pane falls back to the active workspace.
    property int hoveredWs: 0

    // Hyprland reports absolute desktop coordinates; fold them back onto a
    // single screen so windows on any monitor land inside the mini-map.
    function normalize(v, span) {
        return ((v % span) + span) % span;
    }

    signal switchRequested(var wsId)
    signal focusRequested(string address)

    function windowsOn(wsId) {
        var out = [];
        for (var i = 0; i < tab.clients.length; i++) {
            var c = tab.clients[i];
            if (c.workspace && c.workspace.id === wsId)
                out.push(c);
        }
        return out;
    }

    // Same icon resolution the Super+Tab overview uses, so both agree on what
    // an app looks like: a real themed icon where one exists, emoji otherwise.
    function iconName(cls) {
        var k = (cls || "").toLowerCase();
        if (k.indexOf("brave") !== -1) return "brave-desktop";
        if (k.indexOf("ghostty") !== -1) return "com.mitchellh.ghostty";
        if (k.indexOf("code") !== -1 || k.indexOf("vsc") !== -1) return "code";
        if (k.indexOf("discord") !== -1 || k.indexOf("webcord") !== -1) return "discord";
        if (k.indexOf("alacritty") !== -1) return "alacritty";
        if (k.indexOf("kitty") !== -1) return "kitty";
        if (k.indexOf("firefox") !== -1) return "firefox";
        if (k.indexOf("spotify") !== -1) return "spotify";
        if (k.indexOf("thunar") !== -1) return "org.xfce.thunar";
        if (k.indexOf("dolphin") !== -1) return "org.kde.dolphin";
        return k;
    }

    function glyphFor(cls) {
        var k = (cls || "").toLowerCase();
        if (k.indexOf("ghostty") !== -1 || k.indexOf("term") !== -1 || k.indexOf("alacritty") !== -1 || k.indexOf("kitty") !== -1) return "💻";
        if (k.indexOf("brave") !== -1 || k.indexOf("firefox") !== -1 || k.indexOf("chrom") !== -1) return "🌐";
        if (k.indexOf("code") !== -1 || k.indexOf("vsc") !== -1) return "📝";
        if (k.indexOf("discord") !== -1 || k.indexOf("webcord") !== -1) return "💬";
        if (k.indexOf("spotify") !== -1) return "🎵";
        if (k.indexOf("obsidian") !== -1) return "🔮";
        if (k.indexOf("thunar") !== -1 || k.indexOf("dolphin") !== -1 || k.indexOf("file") !== -1) return "📁";
        return "📦";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Item { Layout.fillHeight: true }

        GridLayout {
            id: wsGrid
            Layout.fillWidth: true
            columns: 5
            rows: 2
            columnSpacing: 14
            rowSpacing: 14

            // 16:9 tiles, derived from the grid width rather than each tile's
            // own width so the height binding can't chase the layout.
            readonly property real tileWidth: (width - columnSpacing * (columns - 1)) / columns
            readonly property real tileHeight: tileWidth * 9 / 16

            Repeater {
                model: 10
                delegate: Card {
                    id: wsTile

                    readonly property int wsId: modelData + 1
                    readonly property var wsWindows: tab.windowsOn(wsId)
                    readonly property bool isActive: wsId === tab.activeWs

                    Layout.fillWidth: true
                    Layout.preferredHeight: wsGrid.tileHeight

                    color: isActive ? Theme.cardHover : (tileMouse.containsMouse ? Theme.card : Theme.cardAlt)
                    border.color: isActive ? Theme.borderStrong : Theme.border
                    border.width: isActive ? 2 : 1
                    scale: tileMouse.pressed ? 0.98 : (tileMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.05 } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.switchRequested(wsTile.wsId)
                        onEntered: tab.hoveredWs = wsTile.wsId
                        onExited: if (tab.hoveredWs === wsTile.wsId) tab.hoveredWs = 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    radius: 6
                                    color: wsTile.isActive ? Theme.accent : "#12ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsTile.wsId
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: wsTile.isActive ? "#0a0a0f" : Theme.textSecondary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: wsTile.wsWindows.length > 0 ? wsTile.wsWindows.length : ""
                                    font.pixelSize: 10
                                    color: Theme.textFaint
                                }
                            }

                            // Spatial mini-map: each window sits where it
                            // actually is, at its actual relative size. The
                            // map is letterboxed to the screen's aspect ratio
                            // so the layout isn't distorted by the tile shape.
                            Item {
                                id: spatial
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property real ratio: tab.screenH > 0 ? tab.screenW / tab.screenH : 1.6
                                readonly property real mapW: Math.min(width, height * ratio)
                                readonly property real mapH: ratio > 0 ? mapW / ratio : 0
                                readonly property real originX: (width - mapW) / 2
                                readonly property real originY: (height - mapH) / 2
                                readonly property real sx: tab.screenW > 0 ? mapW / tab.screenW : 0
                                readonly property real sy: tab.screenH > 0 ? mapH / tab.screenH : 0

                                // Screen outline, so an empty workspace still
                                // reads as a screen rather than blank space.
                                Rectangle {
                                    x: spatial.originX
                                    y: spatial.originY
                                    width: spatial.mapW
                                    height: spatial.mapH
                                    radius: 4
                                    color: "transparent"
                                    border.color: "#0affffff"
                                    border.width: 1
                                }

                                Repeater {
                                    model: wsTile.wsWindows
                                    delegate: Rectangle {
                                        id: winRect

                                        x: spatial.originX + tab.normalize(modelData.at ? modelData.at[0] : 0, tab.screenW) * spatial.sx
                                        y: spatial.originY + tab.normalize(modelData.at ? modelData.at[1] : 0, tab.screenH) * spatial.sy
                                        width: Math.max((modelData.size ? modelData.size[0] : 0) * spatial.sx, 6)
                                        height: Math.max((modelData.size ? modelData.size[1] : 0) * spatial.sy, 6)

                                        radius: 3
                                        color: winMouse.containsMouse ? Theme.cardHover : "#1cffffff"
                                        border.color: winMouse.containsMouse ? Theme.borderStrong : "#22ffffff"
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Image {
                                            id: appIcon
                                            anchors.centerIn: parent
                                            width: Math.min(16, Math.min(parent.width, parent.height) - 4)
                                            height: width
                                            sourceSize.width: 32
                                            sourceSize.height: 32
                                            source: "image://icon/" + tab.iconName(modelData.class)
                                            visible: status === Image.Ready && width >= 8
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: tab.glyphFor(modelData.class)
                                            font.pixelSize: Math.min(12, Math.min(parent.width, parent.height) - 4)
                                            visible: appIcon.status !== Image.Ready
                                                     && Math.min(parent.width, parent.height) >= 12
                                        }

                                        MouseArea {
                                            id: winMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: tab.focusRequested(modelData.address)
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: wsTile.wsWindows.length === 0
                                    text: "empty"
                                    font.pixelSize: 9
                                    color: Theme.textFaint
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: "Click a workspace to switch  ·  click an app to focus it"
            font.pixelSize: 10
            color: Theme.textFaint
        }

        // 16:9 tiles can only grow as wide as the grid allows, so they never
        // consume the full height. Spend the remainder on the window list for
        // whichever workspace is hovered, falling back to the active one.
        Card {
            id: detail
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.maximumHeight: 210
            Layout.topMargin: 6

            readonly property int shownWs: tab.hoveredWs > 0 ? tab.hoveredWs : tab.activeWs
            readonly property var shownWindows: tab.windowsOn(shownWs)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "WORKSPACE " + detail.shownWs
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.textMuted
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: detail.shownWindows.length + " window"
                              + (detail.shownWindows.length === 1 ? "" : "s")
                        font.pixelSize: 10
                        color: Theme.textFaint
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Repeater {
                        model: detail.shownWindows
                        delegate: Rectangle {
                            width: Math.min(300, chipRow.implicitWidth + 22)
                            height: 30
                            radius: Theme.radiusSmall
                            color: chipMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                            border.color: chipMouse.containsMouse ? Theme.borderStrong : Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 7

                                Image {
                                    id: chipIcon
                                    Layout.preferredWidth: 15
                                    Layout.preferredHeight: 15
                                    sourceSize.width: 32
                                    sourceSize.height: 32
                                    source: "image://icon/" + tab.iconName(modelData.class)
                                    visible: status === Image.Ready
                                }
                                Text {
                                    text: tab.glyphFor(modelData.class)
                                    font.pixelSize: 12
                                    visible: chipIcon.status !== Image.Ready
                                }
                                Text {
                                    text: modelData.title || modelData.class || "Window"
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 240
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tab.focusRequested(modelData.address)
                            }
                        }
                    }
                }
            }
        }

        // Leftover height reads as panel background rather than an empty card.
        Item { Layout.fillHeight: true }
    }
}
