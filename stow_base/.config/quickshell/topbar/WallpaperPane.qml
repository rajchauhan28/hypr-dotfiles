import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pane

    // Not `data`: that is a reserved Item property. Not `data_` either — a
    // trailing underscore does not produce the handler name QML expects, so
    // the change handler silently never ran and the carousel ignored which
    // wallpaper was actually applied.
    property var info: ({})
    signal apply(string path)

    readonly property var items: (info && info.items) ? info.items : []
    readonly property var swatches: (info && info.palette) ? info.palette : []

    // Browsing position. Starts on whatever is actually applied and follows it
    // when the wallpaper changes underneath us, but a manual browse wins until
    // the applied wallpaper moves again.
    property int cursor: 0
    property int lastAppliedIndex: -1

    onInfoChanged: {
        var idx = (info && info.index !== undefined) ? info.index : -1;
        // Count comes from `info` directly, NOT from the derived `items`
        // binding: that binding has not re-evaluated yet while this handler
        // runs, so it still reads 0 and the clamp below would stomp the
        // cursor back to the first wallpaper every time.
        var count = (info && info.items) ? info.items.length : 0;

        if (idx >= 0 && idx !== pane.lastAppliedIndex) {
            pane.lastAppliedIndex = idx;
            pane.cursor = idx;
        }
        if (count > 0 && pane.cursor >= count)
            pane.cursor = count - 1;
    }

    function at(i) {
        if (!pane.items.length)
            return null;
        var n = ((i % pane.items.length) + pane.items.length) % pane.items.length;
        return pane.items[n];
    }

    function step(d) {
        if (pane.items.length)
            pane.cursor = ((pane.cursor + d) % pane.items.length + pane.items.length)
                          % pane.items.length;
    }

    function humanSize(bytes) {
        if (!bytes)
            return "";
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + " MB";
        return Math.round(bytes / 1024) + " KB";
    }

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "WALLPAPER"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            color: Theme.textMuted
        }
        Item { Layout.fillWidth: true }
        Text {
            text: pane.items.length ? (pane.cursor + 1) + " / " + pane.items.length : "—"
            font.pixelSize: 9
            color: Theme.textFaint
        }
    }

    // ---- Palette from the active wallpaper (wallust/pywal output) ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: pane.swatches.length > 0

        Repeater {
            model: pane.swatches
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 16
                radius: 5
                color: modelData
                border.color: "#22ffffff"
                border.width: 1
            }
        }
    }

    // ---- Carousel: previous | current | next ----
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        Repeater {
            model: [-1, 0, 1]
            delegate: Rectangle {
                readonly property int offset: modelData
                readonly property bool centre: offset === 0
                readonly property var entry: pane.at(pane.cursor + offset)

                Layout.fillHeight: true
                Layout.preferredWidth: centre ? 3 : 1
                Layout.fillWidth: true
                Layout.topMargin: centre ? 0 : 10
                Layout.bottomMargin: centre ? 0 : 10

                radius: Theme.radiusSmall
                color: Theme.cardAlt
                border.color: centre ? (thumbMouse.containsMouse ? Theme.accent : Theme.borderStrong)
                                     : Theme.border
                border.width: centre ? 2 : 1
                opacity: centre ? 1.0 : 0.5
                clip: true
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: 2
                    source: parent.entry && parent.entry.thumb ? "file://" + parent.entry.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: parent.centre ? 480 : 200
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰋩"
                    font.pixelSize: 20
                    color: Theme.textFaint
                    visible: thumb.status !== Image.Ready
                }

                // Video badge
                Rectangle {
                    visible: parent.entry && parent.entry.video
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 18
                    height: 14
                    radius: 4
                    color: "#cc000000"

                    Text {
                        anchors.centerIn: parent
                        text: "󰐊"
                        font.pixelSize: 9
                        color: "#ffffff"
                    }
                }

                // Marks the wallpaper that is actually applied right now.
                Rectangle {
                    visible: pane.info && pane.info.index !== undefined
                             && pane.info.index === ((pane.cursor + parent.offset) % pane.items.length
                                                      + pane.items.length) % Math.max(1, pane.items.length)
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.good
                }

                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.centre) {
                            if (parent.entry)
                                pane.apply(parent.entry.path);
                        } else {
                            pane.step(parent.offset);
                        }
                    }
                    onWheel: wheel => pane.step(wheel.angleDelta.y > 0 ? -1 : 1)
                }
            }
        }
    }

    // ---- Name + details ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: pane.at(pane.cursor) ? pane.at(pane.cursor).name : "No wallpapers found"
            font.pixelSize: 11
            font.bold: true
            color: Theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: {
                var e = pane.at(pane.cursor);
                if (!e)
                    return "";
                var bits = [e.ext.toUpperCase()];
                if (e.w > 0 && e.h > 0)
                    bits.push(e.w + "×" + e.h);
                var s = pane.humanSize(e.size);
                if (s)
                    bits.push(s);
                return bits.join("  ·  ");
            }
            font.pixelSize: 9
            color: Theme.textMuted
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
