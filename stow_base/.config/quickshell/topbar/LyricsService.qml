pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lyrics state for the current track, shared by every view that shows them.
//
// This used to live inside LyricsPane. It moved out when the pop-out window
// arrived: two panes each running their own lyrics.py would double every
// LRCLIB request and, worse, drift apart -- each keeping its own interpolated
// clock, so the dashboard and the floating window would highlight different
// lines of the same song.
Singleton {
    id: svc

    // "idle" | "loading" | "ok" | "none" | "instrumental" | "error"
    property string state: "idle"
    property bool synced: false
    property string message: ""
    property var lines: []

    // MediaService only ticks its position once a second, which is too coarse
    // here: a line would light up as much as a second late and the karaoke
    // fill would advance in visible steps. This interpolates between those
    // updates and re-syncs hard whenever a real position lands.
    property real pos: 0

    Connections {
        target: MediaService
        function onPositionChanged() { svc.pos = MediaService.position; }
    }

    Timer {
        interval: 100
        repeat: true
        // MediaService.active already means "some surface is showing media
        // state", which is exactly when interpolating is worth it.
        running: MediaService.active && MediaService.playing && svc.synced
        onTriggered: svc.pos += 0.1
    }

    // Index of the line that should be lit: the last one whose timestamp has
    // passed. -1 before the first line, which is the intro with no words yet.
    readonly property int activeIndex: {
        if (!svc.synced || svc.lines.length === 0)
            return -1;
        var lo = 0, hi = svc.lines.length - 1, ans = -1;
        while (lo <= hi) {
            var mid = (lo + hi) >> 1;
            if (svc.lines[mid].t <= svc.pos) {
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
        if (svc.activeIndex < 0 || svc.activeIndex >= svc.lines.length)
            return 0;
        var start = svc.lines[svc.activeIndex].t;
        var end;
        if (svc.activeIndex + 1 < svc.lines.length)
            end = svc.lines[svc.activeIndex + 1].t;
        else
            end = MediaService.length > start ? MediaService.length : start + 4;
        if (end <= start)
            return 1;
        return Math.max(0, Math.min(1, (svc.pos - start) / (end - start)));
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
        onTriggered: svc.fetch()
    }

    function fetch() {
        if (!MediaService.hasPlayer || MediaService.title === "") {
            svc.state = "idle";
            svc.lines = [];
            svc.message = "";
            return;
        }
        svc.state = "loading";
        svc.lines = [];
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

    Component.onCompleted: svc.fetch()

    Process {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    svc.state = d.state || "error";
                    svc.synced = !!d.synced;
                    svc.lines = d.lines || [];
                    svc.message = d.message || "";
                } catch (e) {
                    svc.state = "error";
                    svc.synced = false;
                    svc.lines = [];
                    svc.message = "Could not read lyrics";
                }
                svc.pos = MediaService.position;
            }
        }
    }

    // ---- Pop-out window ------------------------------------------------
    // Owned here rather than by either pane so the button in the dashboard
    // and the `qs ipc call lyrics toggle` hook drive the same one window.
    property bool popoutOpen: false

    // The popout is a media surface in its own right, so it has to keep
    // MediaService awake; otherwise position stops advancing the moment the
    // dashboard closes and the highlighted line freezes mid-song.
    onPopoutOpenChanged: MediaService.activeForPopout = svc.popoutOpen

    function togglePopout() { svc.popoutOpen = !svc.popoutOpen; }
}
