import QtQuick
import QtQuick.Layouts

// Lyrics view. All state lives in LyricsService so that the dashboard pane and
// the floating pop-out stay on the same line of the same song.
//
// Synced lyrics (LRC timestamps) get the full treatment: the list keeps the
// current line centred and the line itself fills left-to-right across its own
// duration, karaoke style. Unsynced lyrics fall back to a plain scrollable
// block, because animating a line whose timing is unknown would be inventing
// information the source never gave us.
ColumnLayout {
    id: pane

    spacing: 8

    // The pop-out shows no button of its own -- it would just close and
    // reopen itself -- and it scales the type up, since it is read from
    // further away than a dashboard card.
    property bool showPopoutButton: true
    property int baseFontSize: 12
    property int activeFontSize: 14
    property bool showHeader: true

    // ---- Header -------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: pane.showHeader

        Text {
            text: "LYRICS"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.2
            color: Theme.textMuted
        }

        Item { Layout.fillWidth: true }

        // Synced vs plain is worth stating: it is the difference between the
        // pane following the song and it just showing a wall of text.
        Rectangle {
            visible: LyricsService.state === "ok"
            implicitWidth: badge.implicitWidth + 14
            implicitHeight: 17
            radius: 6
            color: LyricsService.synced
                   ? Qt.rgba(MediaService.accent.r, MediaService.accent.g,
                             MediaService.accent.b, 0.16)
                   : Theme.cardAlt
            border.color: Theme.border
            border.width: 1

            Text {
                id: badge
                anchors.centerIn: parent
                text: LyricsService.synced ? "SYNCED" : "PLAIN"
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 0.8
                color: LyricsService.synced ? MediaService.accent : Theme.textMuted
            }
        }

        // Pop out into a floating window.
        Rectangle {
            visible: pane.showPopoutButton
            implicitWidth: 20
            implicitHeight: 17
            radius: 6
            color: popMouse.containsMouse ? Theme.cardHover : "transparent"
            border.color: LyricsService.popoutOpen ? MediaService.accent : Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                // Box-with-arrow: the usual "open in its own window" glyph.
                text: "↗"
                font.pixelSize: 10
                color: LyricsService.popoutOpen ? MediaService.accent : Theme.textMuted
            }

            MouseArea {
                id: popMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: LyricsService.togglePopout()
            }
        }

        Text {
            text: "lrclib"
            font.pixelSize: 9
            color: Theme.textFaint
        }
    }

    // ---- Status line (everything that is not a lyric) -----------------
    Text {
        Layout.fillWidth: true
        visible: LyricsService.state !== "ok"
        text: {
            if (LyricsService.state === "loading")
                return "Searching lrclib...";
            if (LyricsService.state === "idle")
                return "Nothing playing";
            if (LyricsService.state === "instrumental")
                return "Instrumental";
            return LyricsService.message !== "" ? LyricsService.message
                                                : "No lyrics found";
        }
        font.pixelSize: 11
        color: Theme.textFaint
        wrapMode: Text.WordWrap
    }

    // ---- Lyrics -------------------------------------------------------
    ListView {
        id: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: LyricsService.state === "ok"
        clip: true
        model: LyricsService.lines
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds

        currentIndex: LyricsService.activeIndex

        // Keeping the current line pinned mid-pane is what produces the
        // scrolling-lyrics feel; without it the view would only jump once a
        // line fell off the bottom. Only meaningful when synced -- for plain
        // lyrics there is no current line, so the user scrolls it themselves.
        highlightRangeMode: LyricsService.synced ? ListView.StrictlyEnforceRange
                                                 : ListView.NoHighlightRange
        preferredHighlightBegin: Math.max(0, height / 2 - 22)
        preferredHighlightEnd: Math.max(1, height / 2 + 22)
        highlightMoveDuration: 420
        highlightMoveVelocity: -1

        delegate: Item {
            id: lineRow

            required property var modelData
            required property int index

            readonly property bool isActive: LyricsService.synced
                                             && index === LyricsService.activeIndex
            readonly property bool isPast: LyricsService.synced
                                           && index < LyricsService.activeIndex
            // A blank LRC line is a real instrumental gap, not padding to trim.
            readonly property bool isGap: (modelData.text || "") === ""

            width: list.width
            height: isGap ? 10 : lineText.implicitHeight + 4

            Text {
                id: lineText
                width: parent.width
                visible: !lineRow.isGap
                text: lineRow.modelData.text || ""
                wrapMode: Text.WordWrap
                font.pixelSize: lineRow.isActive ? pane.activeFontSize
                                                 : pane.baseFontSize
                font.bold: lineRow.isActive
                // Sung lines dim rather than vanish, so you keep the thread of
                // where you are in the song.
                color: !LyricsService.synced ? Theme.textSecondary
                       : (lineRow.isActive ? Theme.textPrimary
                       : (lineRow.isPast ? Theme.textFaint : Theme.textMuted))

                Behavior on font.pixelSize { NumberAnimation { duration: 180 } }
                Behavior on color { ColorAnimation { duration: 220 } }
            }

            // Karaoke fill: the same text painted in the accent colour and
            // revealed left-to-right across the line's own duration. Drawn as
            // a clipped copy rather than a gradient on the original because a
            // gradient cannot follow wrapped text across lines.
            Item {
                x: lineText.x
                y: lineText.y
                height: lineText.height
                width: lineText.width * LyricsService.activeFraction
                visible: lineRow.isActive && LyricsService.synced
                clip: true

                Text {
                    width: lineText.width
                    text: lineText.text
                    wrapMode: Text.WordWrap
                    font: lineText.font
                    color: MediaService.accent
                }
            }
        }
    }
}
