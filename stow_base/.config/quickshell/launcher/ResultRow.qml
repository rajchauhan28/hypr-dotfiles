import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// One row in the result list. Deliberately dumb: it paints what it is handed
// and reports clicks upward. All ranking and activation lives in the panel.
Item {
    id: row

    property string label: ""
    property string sublabel: ""
    property string iconName: ""
    property bool selected: false

    // Rich preview, resolved by launcher/clippreview.sh. Empty previewKind
    // means "just use iconName", which is the case for every non-clipboard row.
    //   image / video -> still frame (a video's is a generated thumbnail)
    //   animated      -> GIF, played in place
    //   icon          -> comma-separated freedesktop icon names, best first
    property string previewKind: ""
    property string previewPath: ""

    // Clipboard rows are taller so a preview is actually legible.
    property int rowH: Theme.rowHeight
    property int mediaW: Theme.iconSize
    property int mediaH: Theme.iconSize

    signal activated
    signal hovered

    implicitHeight: rowH

    // Walk the icon-name candidates and take the first the theme actually has.
    // Themes ship "application-pdf" for some types and only the generic
    // "application-x-generic" for the long tail, so a single guess misses often.
    function resolveIcon(candidates) {
        if (!candidates)
            return "";
        var names = candidates.split(",");
        for (var i = 0; i < names.length; i++) {
            var n = names[i].trim();
            if (n === "")
                continue;
            var p = Quickshell.iconPath(n, true);
            if (p !== "")
                return p;
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: Theme.radiusSmall
        color: row.selected ? Theme.rowSelected : "transparent"
        // The same hairline every other card in the shell carries. Without it
        // the selection is a bare wash of colour with no edge to it.
        border.width: 1
        border.color: row.selected ? Theme.border : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animFast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.animFast }
        }
    }

    // A thin accent bar on the selected row. It reads as a caret without
    // moving the text, so the list does not shift as you arrow through it.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 4
        width: 3
        height: row.selected ? row.rowH * 0.55 : 0
        radius: 2
        color: Theme.accent

        Behavior on height {
            NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOutBack }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 12

        // --- Media / icon slot ---------------------------------------
        Item {
            // Referenced by id, never through `parent`: ClippingRectangle
            // reparents its children into an internal content item, so a
            // `parent.parent` chain from inside it lands on the wrong object
            // and silently evaluates to undefined.
            id: mediaSlot

            Layout.preferredWidth: row.mediaW
            Layout.preferredHeight: row.mediaH
            Layout.alignment: Qt.AlignVCenter

            readonly property bool isStill: row.previewKind === "image" || row.previewKind === "video"
            readonly property bool isAnimated: row.previewKind === "animated"
            readonly property bool isIcon: row.previewKind === "icon"

            // Rounded, cropped frame so a wide screenshot and a tall photo
            // occupy the same slot instead of reflowing the row.
            ClippingRectangle {
                anchors.fill: parent
                visible: mediaSlot.isStill || mediaSlot.isAnimated
                radius: 6
                color: "#00000000"

                Image {
                    anchors.fill: parent
                    visible: mediaSlot.isStill
                    source: mediaSlot.isStill && row.previewPath !== "" ? "file://" + row.previewPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Decode at slot size, not full resolution: a 914x989 PNG
                    // scaled down by the scene graph costs real memory per row.
                    sourceSize.width: row.mediaW * 2
                    sourceSize.height: row.mediaH * 2
                }

                AnimatedImage {
                    anchors.fill: parent
                    visible: mediaSlot.isAnimated
                    source: mediaSlot.isAnimated && row.previewPath !== "" ? "file://" + row.previewPath : ""
                    fillMode: Image.PreserveAspectCrop
                    // Only the row under the cursor animates; a list of GIFs all
                    // playing at once is both distracting and a needless load.
                    playing: row.selected
                    cache: true
                }
            }

            // A play glyph is the only thing separating a video thumbnail from
            // a screenshot at this size.
            Rectangle {
                anchors.centerIn: parent
                visible: row.previewKind === "video"
                width: 20; height: 20; radius: 10
                color: "#a0000000"

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: "#ffffff"
                    font.pixelSize: 9
                }
            }

            // File-type icon, as a file manager would show it.
            IconImage {
                anchors.fill: parent
                visible: mediaSlot.isIcon
                source: mediaSlot.isIcon ? row.resolveIcon(row.previewPath) : ""
                asynchronous: true
            }

            // Plain (non-preview) rows: apps, files, dmenu.
            IconImage {
                anchors.fill: parent
                visible: row.previewKind === "" && row.iconName !== ""
                source: row.iconName
                asynchronous: true
            }

            // Fallback glyph so a missing icon still leaves the row aligned.
            Text {
                anchors.centerIn: parent
                visible: row.previewKind === "" && row.iconName === ""
                text: "•"
                color: Theme.textFaint
                font.pixelSize: Theme.iconSize * 0.7
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.selected ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: 14
                font.weight: row.selected ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                maximumLineCount: 1

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: row.sublabel !== ""
                text: row.sublabel
                color: Theme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: row.hovered()
        onClicked: row.activated()
    }
}
