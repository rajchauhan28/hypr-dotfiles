import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Shapes

Scope {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/sidepanel/syspanel.py"

    property bool revealed: false
    property var sys: ({})

    // The JSON is absent until the first poll lands, and all of these are read
    // during the very first layout pass.
    readonly property var bright: (sys && sys.brightness) ? sys.brightness : ({ available: false, percent: 0 })
    readonly property var vol: (sys && sys.volume) ? sys.volume : ({ available: false, percent: 0, muted: false })
    readonly property var mic: (sys && sys.mic) ? sys.mic : ({ available: false, percent: 0, muted: false })
    readonly property var bt: (sys && sys.bluetooth) ? sys.bluetooth : ({ available: false, powered: false, devices: [] })
    readonly property var net: (sys && sys.wifi) ? sys.wifi : ({ available: false, enabled: false, ssid: "" })

    readonly property bool btConnected: {
        var devs = bt.devices || [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i].connected)
                return true;
        return false;
    }

    // While the user is scrolling, the displayed value comes from here rather
    // than from `sys`: a poll landing between the scroll and the apply would
    // otherwise snap the read-out back to the old number.
    property int pendBrightness: -1
    property int pendVolume: -1
    property int pendMic: -1

    readonly property int brightnessValue: pendBrightness >= 0 ? pendBrightness : (bright.percent || 0)
    readonly property int volumeValue: pendVolume >= 0 ? pendVolume : (vol.percent || 0)
    readonly property int micValue: pendMic >= 0 ? pendMic : (mic.percent || 0)

    // ---- Scroll read-out ---------------------------------------------
    property string osdText: ""
    property real osdY: 0
    property bool osdOn: false

    function showOsd(value, slotIndex) {
        root.osdText = value + "%";
        root.osdY = Theme.stripPadding + slotIndex * Theme.iconSlot + Theme.iconSlot / 2;
        root.osdOn = true;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 900
        repeat: false
        onTriggered: root.osdOn = false
    }

    // ---- Action plumbing ---------------------------------------------
    // Queued rather than fired straight at the Process: scrolling produces
    // actions faster than they complete, and starting a Quickshell Process that
    // is already running loses the command.
    property var queue: []

    function act(args) {
        var q = root.queue.slice();
        q.push(args);
        root.queue = q;
        root.pump();
    }

    function pump() {
        if (actionProc.running || root.queue.length === 0)
            return;
        var q = root.queue.slice();
        var a = q.shift();
        root.queue = q;
        actionProc.command = ["python3", root.script].concat(a);
        actionProc.running = true;
    }

    function ingest(text) {
        try {
            root.sys = JSON.parse(text.trim());
            root.pendBrightness = -1;
            root.pendVolume = -1;
            root.pendMic = -1;
        } catch (e) {}
    }

    Process {
        id: actionProc
        stdout: SplitParser { onRead: data => root.ingest(data) }
        onExited: root.pump()
    }

    Process {
        id: statusProc
        // --lite: the strip shows radio state and mute state only, so the
        // Wi-Fi scan list, the sink list and the full Bluetooth enumeration
        // are all skipped. Halves the poll cost.
        command: ["python3", root.script, "status", "--lite"]
        // Seed volume/brightness even when the strip has not been opened yet,
        // so the first media-key IPC step starts from the real current value.
        running: true
        stdout: SplitParser { onRead: data => root.ingest(data) }
    }

    // Scroll steps are coalesced: one apply ~120ms after the last notch,
    // instead of a subprocess per notch.
    Timer {
        id: applyTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (root.pendBrightness >= 0)
                root.act(["brightness", String(root.pendBrightness)]);
            if (root.pendVolume >= 0)
                root.act(["volume", String(root.pendVolume)]);
            if (root.pendMic >= 0)
                root.act(["mic", String(root.pendMic)]);
        }
    }

    function step(current, delta) {
        return Math.max(0, Math.min(100, current + delta * 5));
    }

    function launch(cmd) {
        // setsid so the app outlives this shell -- a Quickshell Process is a
        // child, and restarting the panel would otherwise kill the window.
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["sh", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"];
        p.running = true;
    }

    // Only polls while open; a hidden strip costs nothing.
    Timer {
        interval: 4000
        running: root.revealed
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!actionProc.running) statusProc.running = true
    }

    IpcHandler {
        target: "sidepanel"

        // open/close rather than show/hide: `qs ipc` owns the name `show`.
        function toggle(): void { hideTimer.stop(); root.revealed = !root.revealed; }
        function open(): void { hideTimer.stop(); root.revealed = true; }
        function close(): void { hideTimer.stop(); root.revealed = false; }

        // Same path the scroll wheel takes, so media keys can drive the strip
        // (and its read-out) without the panel being open. delta is in notches.
        function volume(delta: int): void {
            root.pendVolume = root.step(root.volumeValue, delta);
            root.showOsd(root.pendVolume, 1);
            applyTimer.restart();
        }
        function brightness(delta: int): void {
            root.pendBrightness = root.step(root.brightnessValue, delta);
            root.showOsd(root.pendBrightness, 0);
            applyTimer.restart();
        }
        function micvol(delta: int): void {
            root.pendMic = root.step(root.micValue, delta);
            root.showOsd(root.pendMic, 2);
            applyTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 320
        repeat: false
        onTriggered: root.revealed = false
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; right: true }

        exclusiveZone: 0
        // Wide enough to paint the read-out beside the strip; only the strip
        // itself is ever inside the input mask.
        implicitWidth: Theme.edgeLine + Theme.panelWidth + Theme.osdWidth
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-sidepanel"

        // The pointer counts as inside if EITHER handler sees it. Reacting to
        // each handler separately is last-call-wins: once the body slides over
        // the pointer it takes hover from the hotspot, whose false would start
        // the hide timer and bounce the panel shut.
        readonly property bool pointerInside: hotspotHover.hovered || stripHover.hovered
        onPointerInsideChanged: {
            if (pointerInside) {
                hideTimer.stop();
                root.revealed = true;
            } else if (root.revealed) {
                hideTimer.restart();
            }
        }

        mask: Region {
            item: root.revealed ? openMask : hotspot
        }

        // --- Trigger strip: right 15px, middle 10% of the screen ---
        Item {
            id: hotspot
            width: Theme.hotspotWidth
            height: Math.round(win.height * Theme.hotspotHeightFraction)
            x: win.width - width
            y: Math.round((win.height - height) / 2)

            HoverHandler { id: hotspotHover }
        }

        // Input region while open. Geometry is deliberately STATIC: deriving it
        // from the animating body made the region collapse during the slide-in,
        // so the pointer fell through and the panel flickered. It stops at the
        // strip -- the read-out area must stay click-through.
        Item {
            id: openMask
            x: win.width - Theme.edgeLine - Theme.panelWidth
            y: win.bodyTop - Theme.cornerFillet
            width: Theme.edgeLine + Theme.panelWidth
            height: Theme.panelHeight + Theme.cornerFillet * 2
        }

        // --- Geometry shared by silhouette, mask and content ---
        readonly property real railX: width - Theme.edgeLine
        readonly property real bodyTop: Math.round((height - Theme.panelHeight) / 2)
        readonly property real bodyBottom: bodyTop + Theme.panelHeight

        // The body grows leftward out of the rail rather than sliding in as a
        // detached card, so it is the WIDTH that animates.
        property real bodyWidth: root.revealed ? Theme.panelWidth : 0
        Behavior on bodyWidth {
            NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
        }

        readonly property real bodyLeft: railX - bodyWidth
        // Both radii shrink with the body so the shape stays sane at width 0.
        readonly property real filletR: Math.min(Theme.cornerFillet, bodyWidth)
        readonly property real cornerR: Math.min(Theme.radiusPanel, bodyWidth / 2)

        // --- Rail + body drawn as ONE closed path ---
        // A Rectangle cannot produce the concave join where the body meets the
        // rail, so the whole silhouette is a single filled path: a full-height
        // rail down the right edge flaring out into the body beside it.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                fillColor: Theme.panelBg
                strokeColor: Theme.panelBorder
                strokeWidth: 1

                startX: win.width
                startY: 0

                PathLine { x: win.width; y: win.height }
                PathLine { x: win.railX; y: win.height }

                // Concave scoop joining rail to body. The control point sits at
                // the inner corner, where the two tangent lines meet: the curve
                // leaves the rail vertically and arrives at the body edge
                // horizontally. Control at the outer corner reverses both
                // tangents and bulges outward instead.
                PathLine { x: win.railX; y: win.bodyBottom + win.filletR }
                PathQuad {
                    x: win.railX - win.filletR
                    y: win.bodyBottom
                    controlX: win.railX
                    controlY: win.bodyBottom
                }

                PathLine { x: win.bodyLeft + win.cornerR; y: win.bodyBottom }
                PathQuad {
                    x: win.bodyLeft
                    y: win.bodyBottom - win.cornerR
                    controlX: win.bodyLeft
                    controlY: win.bodyBottom
                }

                PathLine { x: win.bodyLeft; y: win.bodyTop + win.cornerR }
                PathQuad {
                    x: win.bodyLeft + win.cornerR
                    y: win.bodyTop
                    controlX: win.bodyLeft
                    controlY: win.bodyTop
                }

                // mirrored scoop at the top
                PathLine { x: win.railX - win.filletR; y: win.bodyTop }
                PathQuad {
                    x: win.railX
                    y: win.bodyTop - win.filletR
                    controlX: win.railX
                    controlY: win.bodyTop
                }

                PathLine { x: win.railX; y: 0 }
                PathLine { x: win.width; y: 0 }
            }
        }

        // --- Scroll read-out, floating beside the strip ---
        // Outside the clipper and outside the input mask: it is a transient
        // overlay, so it must never block a click or hold the panel open.
        Text {
            id: osd
            text: root.osdText
            font.pixelSize: 44
            font.bold: true
            color: Theme.textPrimary
            // Not gated on `revealed`: driven over IPC this doubles as a media
            // OSD while the strip is still hidden.
            opacity: root.osdOn ? 0.45 : 0.0
            horizontalAlignment: Text.AlignRight

            width: Theme.osdWidth - 16
            x: win.bodyLeft - width - 12
            y: win.bodyTop + root.osdY - height / 2

            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }
            Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }
        }

        // --- Icon strip, clipped to the growing body ---
        Item {
            id: strip
            x: win.bodyLeft
            y: win.bodyTop
            width: win.bodyWidth
            height: Theme.panelHeight
            clip: true
            opacity: root.revealed ? 1.0 : 0.0
            scale: root.revealed ? 1.0 : 0.98

            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }
            Behavior on scale { NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutQuint } }

            HoverHandler { id: stripHover }

            // Laid out at full WIDTH inside the clipper so the reveal wipes the
            // icons into view instead of re-running the layout every frame.
            Column {
                x: (Theme.panelWidth - Theme.iconSlot) / 2
                y: Theme.stripPadding
                width: Theme.iconSlot

                IconButton {
                    glyph: "󰃠"
                    available: root.bright.available
                    scrollable: true
                    activeColor: Theme.warn
                    onScrolled: d => {
                        root.pendBrightness = root.step(root.brightnessValue, d);
                        root.showOsd(root.pendBrightness, 0);
                        applyTimer.restart();
                    }
                }

                IconButton {
                    glyph: "󰕾"
                    altGlyph: "󰝟"
                    alt: root.vol.muted || false
                    available: root.vol.available
                    clickable: true
                    scrollable: true
                    onActivated: root.act(["mute", "toggle"])
                    onScrolled: d => {
                        root.pendVolume = root.step(root.volumeValue, d);
                        root.showOsd(root.pendVolume, 1);
                        applyTimer.restart();
                    }
                }

                IconButton {
                    glyph: "󰍬"
                    altGlyph: "󰍭"
                    alt: root.mic.muted || false
                    available: root.mic.available
                    clickable: true
                    scrollable: true
                    onActivated: root.act(["micmute", "toggle"])
                    onScrolled: d => {
                        root.pendMic = root.step(root.micValue, d);
                        root.showOsd(root.pendMic, 2);
                        applyTimer.restart();
                    }
                }

                IconButton {
                    glyph: "󰖩"
                    altGlyph: "󰖪"
                    alt: !root.net.enabled
                    available: root.net.available
                    clickable: true
                    activeColor: root.net.ssid !== "" ? Theme.good : Theme.textPrimary
                    onActivated: root.launch(Quickshell.env("HOME") + "/.local/bin/auralink")
                }

                IconButton {
                    glyph: "󰂯"
                    altGlyph: "󰂲"
                    alt: !root.bt.powered
                    available: root.bt.available
                    clickable: true
                    activeColor: root.btConnected ? Theme.good : Theme.textPrimary
                    onActivated: root.launch(Quickshell.env("HOME") + "/.local/bin/auralink-bt")
                }
            }
        }
    }
}
