import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Lyrics for whatever MediaService is currently following.
//
// Synced lyrics (LRC timestamps) get the full treatment: the list keeps the
// current line centred and the line itself fills left-to-right across its own
// duration, karaoke style. Unsynced lyrics fall back to a plain scrollable
// block, because animating a line whose timing is unknown would be inventing
// information the source never gave us.
ColumnLayout {
    id: pane

    spacing: 8

    // "idle" | "loading" | "ok" | "none" | "instrumental" | "error"
    property string state: "idle"
    property bool synced: false
    property string message: ""
    property var lines: []

    // MediaService only ticks its position once a second, which is too coarse
    // here: a line would light up as much as a second late and the fill would
    // advance in visible steps. This interpolates between those updates and
    // re-syncs hard whenever the real position lands.
    property real pos: 0

    Connections {
        target: MediaService
        function onPositionChanged() { pane.pos = MediaService.position; }
    }

    Timer {
        interval: 100
        repeat: true
        running: pane.visible && MediaService.playing && pane.synced
        onTriggered: pane.pos += 0.1
    }

    // Index of the line that should be lit: the last one whose timestamp has
    // passed. -1 before the first line, which is the intro with no words yet.
    readonly property int activeIndex: {
        if (!pane.synced || pane.lines.length === 0)
            return -1;
        var lo = 0, hi = pane.lines.length - 1, ans = -1;
        while (lo <= hi) {
            var mid = (lo + hi) >> 1;
            if (pane.lines[mid].t <= pane.pos) {
                ans = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return ans;
    }

    // How far through the active line we are, 0..1, used for the fill. The
    // last line has no successor to bound it, so it borrows the track length
    // and falls back to a nominal 4s when even that is unknown.
    readonly property real activeFraction: {
        if (pane.activeIndex < 0 || pane.activeIndex >= pane.lines.length)
            return 0;
        var start = pane.lines[pane.activeIndex].t;
        var end;
        if (pane.activeIndex + 1 < pane.lines.length)
            end = pane.lines[pane.activeIndex + 1].t;
        else
            end = MediaService.length > start ? MediaService.length : start + 4;
        if (end <= start)
            return 1;
        return Math.max(0, Math.min(1, (pane.pos - start) / (end - start)));
    }

    // ---- Fetching -----------------------------------------------------
    // Keyed on the track identity rather than on any single property: title
    // alone repeats across albums, and artUrl churns without the song
    // changing.
    readonly property string trackKey: MediaService.hasPlayer
        ? (MediaService.artist + " :: " + MediaService.title
           + " :: " + MediaService.album)
        : ""

    onTrackKeyChanged: fetchDebounce.restart()

    // A track change rewrites artist/title/album in separate steps, so firing
    // on the first of them would query LRCLIB for a half-updated track.
    Timer {
        id: fetchDebounce
        interval: 250
        repeat: false
        onTriggered: pane.fetch()
    }

    function fetch() {
        if (!MediaService.hasPlayer || MediaService.title === "") {
            pane.state = "idle";
            pane.lines = [];
            pane.message = "";
            return;
        }
        pane.state = "loading";
        pane.lines = [];
        lyricsProc.running = false;
        lyricsProc.command = [
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/topbar/lyrics.py",
            MediaService.artist,
            MediaService.title,
            MediaService.album,
            String(Math.round(MediaService.length))
        ];
        lyricsProc.running = true;
    }

    Component.onCompleted: pane.fetch()

    Process {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    pane.state = d.state || "error";
                    pane.synced = !!d.synced;
                    pane.lines = d.lines || [];
                    pane.message = d.message || "";
                } catch (e) {
                    pane.state = "error";
                    pane.synced = false;
                    pane.lines = [];
                    pane.message = "Could not read lyrics";
                }
                pane.pos = MediaService.position;
            }
        }
    }

    // ---- Header -------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true

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
            visible: pane.state === "ok"
            implicitWidth: badge.implicitWidth + 14
            implicitHeight: 17
            radius: 6
            color: pane.synced ? Qt.rgba(MediaService.accent.r, MediaService.accent.g,
                                         MediaService.accent.b, 0.16)
                               : Theme.cardAlt
            border.color: Theme.border
            border.width: 1

            Text {
                id: badge
                anchors.centerIn: parent
                text: pane.synced ? "SYNCED" : "PLAIN"
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 0.8
                color: pane.synced ? MediaService.accent : Theme.textMuted
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
        visible: pane.state !== "ok"
        text: {
            if (pane.state === "loading")
                return "Searching lrclib...";
            if (pane.state === "idle")
                return "Nothing playing";
            if (pane.state === "instrumental")
                return "Instrumental";
            return pane.message !== "" ? pane.message : "No lyrics found";
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
        visible: pane.state === "ok"
        clip: true
        model: pane.lines
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds

        currentIndex: pane.activeIndex

        // Keeping the current line pinned mid-pane is what produces the
        // scrolling-lyrics feel; without it the view would only jump once a
        // line fell off the bottom. Only meaningful when synced -- for plain
        // lyrics there is no current line, so the user scrolls it themselves.
        highlightRangeMode: pane.synced ? ListView.StrictlyEnforceRange
                                        : ListView.NoHighlightRange
        preferredHighlightBegin: Math.max(0, height / 2 - 22)
        preferredHighlightEnd: Math.max(1, height / 2 + 22)
        highlightMoveDuration: 420
        highlightMoveVelocity: -1

        delegate: Item {
            id: lineRow

            required property var modelData
            required property int index

            readonly property bool isActive: pane.synced && index === pane.activeIndex
            readonly property bool isPast: pane.synced && index < pane.activeIndex
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
                font.pixelSize: lineRow.isActive ? 14 : 12
                font.bold: lineRow.isActive
                // Sung lines dim rather than vanish, so you keep the thread of
                // where you are in the song.
                color: !pane.synced ? Theme.textSecondary
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
                width: lineText.width * pane.activeFraction
                visible: lineRow.isActive && pane.synced
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
