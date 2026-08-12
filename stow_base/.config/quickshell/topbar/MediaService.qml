pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: svc

    // The panel flips these so nothing runs while hidden: `active` gates the
    // playhead, `wantVolume` the sink query, `wantSpectrum` the audio capture.
    property bool active: false
    property bool wantVolume: false
    property bool wantSpectrum: false

    // ---- Players ------------------------------------------------------
    // Mpris is event-driven, so metadata lands the moment it changes instead
    // of up to 3s later like the old `playerctl` poll.
    readonly property var players: Mpris.players ? Mpris.players.values : []

    // A manual pick wins until that player goes away; otherwise whichever
    // player is actually playing does, so starting a video takes over from a
    // paused Spotify without the user choosing.
    property string preferredId: ""

    readonly property var player: {
        var list = svc.players;
        if (list.length === 0)
            return null;
        var i;
        if (svc.preferredId !== "")
            for (i = 0; i < list.length; i++)
                if (list[i].dbusName === svc.preferredId)
                    return list[i];
        for (i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list[0];
    }

    function selectPlayer(dbusName) {
        svc.preferredId = dbusName;
        svc.syncPosition();
    }

    function playerLabel(p) {
        if (!p)
            return "";
        return p.identity || p.desktopEntry || p.dbusName || "Player";
    }

    // ---- Track state (same names the panes already bind to) -----------
    readonly property bool hasPlayer: !!svc.player
    readonly property string title: svc.player ? (svc.player.trackTitle || "Unknown Track") : ""
    readonly property string artist: svc.player ? (svc.player.trackArtist || "Unknown Artist") : ""
    readonly property string album: svc.player ? (svc.player.trackAlbum || "") : ""
    readonly property string artUrl: svc.player ? (svc.player.trackArtUrl || "") : ""
    readonly property bool playing: svc.player ? svc.player.isPlaying : false
    readonly property string status: svc.playing ? "Playing" : (svc.hasPlayer ? "Paused" : "Stopped")
    readonly property real length: svc.player && svc.player.lengthSupported ? svc.player.length : 0
    readonly property bool canSeek: svc.player ? svc.player.canSeek : false
    readonly property bool canNext: svc.player ? svc.player.canGoNext : false
    readonly property bool canPrev: svc.player ? svc.player.canGoPrevious : false

    // Mirrored rather than bound: Quickshell only refreshes MPRIS position when
    // asked, and a local tick between refreshes keeps the bar smooth without
    // hammering DBus.
    property real position: 0

    readonly property real progress: svc.length > 0 ? Math.min(1, svc.position / svc.length) : 0

    property int volume: 0
    property bool muted: false

    function fmtTime(secs) {
        if (!secs || secs < 0)
            return "0:00";
        var m = Math.floor(secs / 60);
        var s = Math.floor(secs % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    function syncPosition() {
        if (svc.player && svc.player.positionSupported)
            svc.position = svc.player.position;
        else
            svc.position = 0;
    }

    function run(args) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', svc);
        p.command = args;
        p.running = true;
    }

    function playPause() { if (svc.player) svc.player.togglePlaying(); }
    function next() { if (svc.player) svc.player.next(); }
    function previous() { if (svc.player) svc.player.previous(); }

    function seekFraction(f) {
        if (!svc.player || !svc.canSeek || svc.length <= 0)
            return;
        var t = Math.max(0, Math.min(svc.length, f * svc.length));
        svc.player.position = t;
        svc.position = t;
    }

    function setVolume(pct) {
        var v = Math.max(0, Math.min(100, Math.round(pct)));
        if (v === svc.volume)
            return;   // dragging emits a lot of these; don't respawn wpctl for no change
        run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (v / 100.0).toFixed(2)]);
        svc.volume = v;
    }
    function toggleMute() {
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        svc.muted = !svc.muted;
    }

    onPlayerChanged: svc.syncPosition()
    onTitleChanged: svc.syncPosition()

    // Re-read the real position periodically; the 1s tick below covers the gaps
    // so the bar moves every second rather than every four.
    Timer {
        interval: 4000
        running: svc.active && svc.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.syncPosition()
    }

    Timer {
        interval: 1000
        running: svc.active && svc.playing && svc.length > 0
        repeat: true
        onTriggered: svc.position = Math.min(svc.length, svc.position + 1)
    }

    // ---- Album-art accent ---------------------------------------------
    // Drives the tab's tint. `artPath` is the local copy, so a remote cover
    // (a browser tab's art) can also be used as the blurred backdrop.
    property string artPath: ""
    property color accent: "#e4e4e7"
    property color glow: "#3f3f46"

    onArtUrlChanged: artTimer.restart()

    // Debounced: a track change can rewrite artUrl several times in a row.
    Timer {
        id: artTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (svc.artUrl === "") {
                svc.artPath = "";
                svc.accent = "#e4e4e7";
                svc.glow = "#3f3f46";
                return;
            }
            artProc.running = false;
            artProc.command = ["python3",
                "/home/reign/.config/quickshell/topbar/artcolor.py", svc.artUrl];
            artProc.running = true;
        }
    }

    Process {
        id: artProc
        stdout: SplitParser {
            onRead: data => {
                try {
                    var d = JSON.parse(data.trim());
                    svc.artPath = d.path || "";
                    svc.accent = d.accent || "#e4e4e7";
                    svc.glow = d.glow || "#3f3f46";
                } catch (e) {}
            }
        }
    }

    // ---- Spectrum ------------------------------------------------------
    // Taps the sink monitor, so it follows whatever is audible rather than the
    // MPRIS player -- a YouTube tab with no MPRIS position still animates.
    readonly property int bandCount: 28
    property var bands: []
    readonly property real level: {
        var b = svc.bands;
        if (!b || b.length === 0)
            return 0;
        var sum = 0;
        for (var i = 0; i < b.length; i++)
            sum += b[i];
        return sum / b.length / 100.0;
    }
    // Bass energy, for pulsing artwork in time with a kick.
    readonly property real bass: {
        var b = svc.bands;
        if (!b || b.length < 4)
            return 0;
        return (b[0] + b[1] + b[2] + b[3]) / 4 / 100.0;
    }

    Process {
        id: spectrumProc
        running: svc.wantSpectrum
        command: ["python3", "/home/reign/.config/quickshell/topbar/spectrum.py",
                  String(svc.bandCount), "30"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    svc.bands = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }

    // Leaving the tab must visibly settle the bars, not freeze them mid-spike.
    onWantSpectrumChanged: if (!wantSpectrum) svc.bands = []

    Timer {
        id: volPoll
        interval: 2000
        running: svc.active && svc.wantVolume
        repeat: true
        triggeredOnStart: true
        onTriggered: volProc.running = true
    }

    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.00'"]
        stdout: SplitParser {
            onRead: data => {
                var txt = data.trim();
                var m = txt.match(/Volume:\s*([0-9.]+)/);
                if (m)
                    svc.volume = Math.round(parseFloat(m[1]) * 100);
                svc.muted = txt.indexOf("MUTED") !== -1;
            }
        }
    }
}
