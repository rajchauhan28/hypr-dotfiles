import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Shapes

ShellRoot {
    id: root

    // ---- Reveal state: two steps ---------------------------------------
    // Step 1: the pointer reaches the top edge and the rail slides down out of
    // it. Step 2: that rail is clicked and the dashboard grows out of the rail.
    // Hover alone no longer opens the dashboard, so brushing the top edge on
    // the way to a window's controls costs nothing but a hairline.
    property bool railShown: false
    property bool revealed: false
    property int tabIndex: 0

    // ---- Data ---------------------------------------------------------
    property var stats: ({})
    property var weather: ({})
    property var clients: []
    property int activeWs: 1
    property date now: new Date()
    property var cpuHistory: []
    property var gpuHistory: []
    property var vramHistory: []
    property var systemTempHistory: []
    property var gpuTempHistory: []
    property var networkDownHistory: []
    property var networkUpHistory: []
    property string lastClientsJson: ""

    readonly property var tabs: [
        { label: "Dashboard", glyph: "󰕮" },
        { label: "Media", glyph: "󰎈" },
        { label: "Performance", glyph: "󰓅" },
        { label: "Workspaces", glyph: "󰕰" }
    ]

    // Every poll costs a subprocess, so each source runs only while the panel
    // is open AND a tab that actually displays it is selected.
    readonly property bool wantStats: revealed && (tabIndex === 0 || tabIndex === 2)
    readonly property bool wantClients: revealed && tabIndex === 3
    readonly property bool wantClock: revealed && tabIndex === 0
    readonly property bool wantMedia: revealed && (tabIndex === 0 || tabIndex === 1)

    onWantMediaChanged: MediaService.activeForPanel = root.wantMedia
    onTabIndexChanged: {
        MediaService.wantVolume = (root.tabIndex === 1);
        // Spectrum runs whenever the topbar panel is open to feed circumference waves
        MediaService.wantSpectrum = revealed;
    }

    // Everything below is gated on `revealed` so a hidden panel costs nothing.
    onRevealedChanged: {
        // Whatever opened the dashboard — a tap, a keybind, IPC — the rail it
        // grows out of has to be down first, or the body would hang in the air.
        if (revealed)
            root.railShown = true;
        MediaService.activeForPanel = root.wantMedia;
        MediaService.wantVolume = revealed && root.tabIndex === 1;
        MediaService.wantSpectrum = revealed;
        if (revealed) {
            root.now = new Date();
        } else {
            // Always come back up on Dashboard rather than wherever the last
            // visit left off.
            root.tabIndex = 0;
        }
    }

    // Only hours and minutes are shown, so a per-second tick would repaint the
    // whole dashboard 60x for nothing. Reveal resets `now` anyway.
    Timer {
        interval: 15000
        running: root.wantClock
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 3000
        running: root.wantStats
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    Timer {
        interval: 2500
        running: root.wantClients
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clientsProc.running = true;
            activeWsProc.running = true;
        }
    }

    property var updates: ({})
    property bool updatesBusy: false

    function refreshUpdates() {
        root.updatesBusy = true;
        updatesProc.running = true;
    }

    function launchTerminal(cmd) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = cmd ? ["ghostty", "-e", "bash", "-c", cmd]
                        : ["ghostty"];
        p.running = true;
    }

    // checkupdates syncs a temp pacman db over the network, so this runs on a
    // slow timer of its own and never blocks the panel opening.
    Timer {
        interval: 1800000   // 30 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshUpdates()
    }

    Process {
        id: updatesProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/topbar/updates.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.updates = JSON.parse(data.trim());
                } catch (e) {}
                root.updatesBusy = false;
            }
        }
    }

    // ---- Wallpapers -------------------------------------------------
    property var wallpapers: ({})

    function refreshWallpapers() { wallpapersProc.running = true; }

    function applyWallpaper(path) {
        // Kill any in-flight run first: setting running=true on an already
        // running Process silently drops the command, so one hung set (say,
        // ffmpeg probing a freshly added video) would eat every click after it.
        wallpaperSetProc.running = false;
        wallpaperSetProc.command = ["python3",
            Quickshell.env("HOME") + "/.config/quickshell/topbar/wallpapers.py", "set", path];
        wallpaperSetProc.running = true;
    }

    Process {
        id: wallpapersProc
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/topbar/wallpapers.py", "list"]
        stdout: SplitParser {
            onRead: data => {
                try { root.wallpapers = JSON.parse(data.trim()); } catch (e) {}
            }
        }
    }

    Process {
        id: wallpaperSetProc
        stdout: SplitParser {
            onRead: data => {
                try { root.wallpapers = JSON.parse(data.trim()); } catch (e) {}
            }
        }
    }

    // ---- Calendar: bookmarks + Indian holidays ------------------------
    // Bookmarks live in the clock widget's existing store, so notes added here
    // show up there too rather than in a second, competing database.
    property var bookmarks: ({})
    property var holidays: ({})
    property bool holidaysComplete: false
    property int holidayYear: 0

    function loadBookmarks() { bookmarksProc.running = true; }

    function addBookmark(dateKey, text) {
        bookmarkWrite.command = ["python3",
            Quickshell.env("HOME") + "/.config/quickshell/topbar/calendar_store.py",
            "add", dateKey, text];
        bookmarkWrite.running = true;
    }

    function deleteBookmark(dateKey, idx) {
        bookmarkWrite.command = ["python3",
            Quickshell.env("HOME") + "/.config/quickshell/topbar/calendar_store.py",
            "delete", dateKey, idx.toString()];
        bookmarkWrite.running = true;
    }

    function loadHolidays(year) {
        if (year === root.holidayYear)
            return;
        root.holidayYear = year;
        holidaysProc.command = ["python3",
            Quickshell.env("HOME") + "/.config/quickshell/topbar/holidays_in.py", year.toString()];
        holidaysProc.running = true;
    }

    Process {
        id: bookmarksProc
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/topbar/calendar_store.py", "list"]
        stdout: SplitParser {
            onRead: data => {
                try { root.bookmarks = JSON.parse(data.trim()) || ({}); } catch (e) {}
            }
        }
    }

    Process {
        id: bookmarkWrite
        stdout: SplitParser {
            onRead: data => {
                try { root.bookmarks = JSON.parse(data.trim()) || ({}); } catch (e) {}
            }
        }
    }

    Process {
        id: holidaysProc
        stdout: SplitParser {
            onRead: data => {
                try {
                    var h = JSON.parse(data.trim());
                    root.holidays = h.days || ({});
                    root.holidaysComplete = !!h.complete;
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: root.loadHolidays(new Date().getFullYear())

    // Weather is slow-moving and needs the network, so it runs on its own
    // schedule whether or not the panel is open.
    Timer {
        interval: 900000   // 15 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: statsProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/topbar/sysinfo.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var s = JSON.parse(data.trim());
                    root.stats = s;
                    var h = root.cpuHistory.slice();
                    h.push(s.cpu || 0);
                    while (h.length > 60)
                        h.shift();
                    root.cpuHistory = h;

                    root.gpuHistory = root.appendSample(root.gpuHistory,
                        s.gpu && !s.gpu.asleep ? (s.gpu.util || 0) : 0);
                    root.vramHistory = root.appendSample(root.vramHistory,
                        s.gpu && s.gpu.memTotal > 0
                            ? 100 * s.gpu.memUsed / s.gpu.memTotal : 0);
                    root.systemTempHistory = root.appendSample(root.systemTempHistory, s.systemTemp || 0);
                    root.gpuTempHistory = root.appendSample(root.gpuTempHistory,
                        s.gpu && !s.gpu.asleep ? (s.gpu.temp || 0) : 0);
                    root.networkDownHistory = root.appendSample(root.networkDownHistory,
                        s.network ? (s.network.down || 0) : 0);
                    root.networkUpHistory = root.appendSample(root.networkUpHistory,
                        s.network ? (s.network.up || 0) : 0);
                } catch (e) {}
            }
        }
    }

    function appendSample(history, value) {
        var samples = history.slice();
        samples.push(value);
        while (samples.length > 60)
            samples.shift();
        return samples;
    }

    Process {
        id: weatherProc
        command: ["bash", "-c",
            "curl -s --max-time 8 'wttr.in/?format=%t|%C|%h|%l' 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length < 4 || data.indexOf("Unknown location") !== -1)
                    return;
                var t = parts[0].replace("+", "").replace("°C", "").trim();
                root.weather = {
                    temp: parseInt(t),
                    desc: parts[1].trim(),
                    humidity: parseInt(parts[2].replace("%", "").trim()),
                    location: parts[3].trim(),
                    icon: root.weatherGlyph(parts[1].trim())
                };
            }
        }
    }

    function weatherGlyph(desc) {
        var d = (desc || "").toLowerCase();
        if (d.indexOf("thunder") !== -1) return "󰙾";
        if (d.indexOf("snow") !== -1 || d.indexOf("sleet") !== -1) return "󰼶";
        if (d.indexOf("rain") !== -1 || d.indexOf("drizzle") !== -1 || d.indexOf("shower") !== -1) return "󰖗";
        if (d.indexOf("fog") !== -1 || d.indexOf("mist") !== -1 || d.indexOf("haze") !== -1) return "󰖑";
        if (d.indexOf("overcast") !== -1) return "󰖐";
        if (d.indexOf("cloud") !== -1) return "󰖕";
        return "󰖙";
    }

    Process {
        id: clientsProc
        command: ["bash", "-c", "hyprctl -j clients | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                var txt = data.trim();
                if (txt === root.lastClientsJson)
                    return;
                try {
                    var parsed = JSON.parse(txt);
                    root.lastClientsJson = txt;
                    root.clients = parsed;
                } catch (e) {}
            }
        }
    }

    // Read once at startup: the workspace mini-maps scale window geometry
    // against this, so it must not be hardcoded.
    property int screenW: 1920
    property int screenH: 1200

    Process {
        id: monitorsProc
        running: true
        command: ["bash", "-c", "hyprctl -j monitors | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var mons = JSON.parse(data.trim());
                    for (var i = 0; i < mons.length; i++) {
                        if (mons[i].focused || i === 0) {
                            root.screenW = mons[i].width || 1920;
                            root.screenH = mons[i].height || 1200;
                            if (mons[i].focused)
                                return;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: activeWsProc
        command: ["bash", "-c", "hyprctl -j activeworkspace | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var p = JSON.parse(data.trim());
                    root.activeWs = p.id || 1;
                } catch (e) {}
            }
        }
    }

    // Reuses the overview's compatibility shim so both agree on how to talk
    // to this Hyprland's Lua dispatch API.
    function dispatchHypr(cmd, arg) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = [Quickshell.env("HOME") + "/.config/quickshell/overview/hyprctl-compat.sh", cmd, arg];
        p.running = true;
    }

    // Lets a keybind pin the panel open without using the hotspot:
    //   qs -c topbar ipc call panel toggle
    IpcHandler {
        target: "panel"

        function toggle(): void {
            root.toggleDashboard();
        }
        // Named open/close rather than show/hide: `qs ipc` has its own `show`
        // subcommand, and the CLI swallows the name before it reaches us.
        function open(): void {
            hideTimer.stop();
            root.railShown = true;
            root.revealed = true;
        }
        function close(): void {
            hideTimer.stop();
            root.revealed = false;
            root.railShown = false;
        }
        // Step 1 on its own: put the rail down without opening the dashboard.
        function rail(): void {
            hideTimer.stop();
            root.railShown = true;
        }
        // Scripting hook: apply a wallpaper through the exact same path the
        // dashboard card's click takes.
        function wallpaper(path: string): void {
            root.applyWallpaper(path);
        }

        function tab(name: string): void {
            for (var i = 0; i < root.tabs.length; i++) {
                if (root.tabs[i].label.toLowerCase() === name.toLowerCase()) {
                    root.tabIndex = i;
                    return;
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 320
        repeat: false
        onTriggered: {
            root.revealed = false;
            root.railShown = false;
        }
    }

    // Hover only ever drives step 1. The dashboard is a deliberate click now,
    // so a pointer resting on the top edge no longer drops a 1280x720 panel
    // over whatever is underneath it.
    function syncHover(hovered) {
        if (hovered) {
            hideTimer.stop();
            root.railShown = true;
        } else if (root.railShown || root.revealed) {
            hideTimer.restart();
        }
    }

    // Step 2. Tapping the rail again closes the dashboard but leaves the rail
    // down, so it can be reopened without moving the pointer away and back.
    //
    // DEBOUNCED, and that is not paranoia: a TapHandler takes only a PASSIVE
    // grab, so a single physical click is delivered to every overlapping item
    // that has one. The trigger strip and the rail overlap at the top centre —
    // precisely where the pointer is when the rail appears — so one click ran
    // this twice, the two toggles cancelled, and clicking the bar looked like
    // it did nothing at all.
    property bool tapCooling: false
    Timer {
        id: tapCooldown
        interval: 250
        repeat: false
        onTriggered: root.tapCooling = false
    }

    function toggleDashboard() {
        if (root.tapCooling)
            return;
        root.tapCooling = true;
        tapCooldown.restart();

        hideTimer.stop();
        root.railShown = true;
        root.revealed = !root.revealed;
    }

    // Click-away dismissal. Idempotent on purpose so it can never fight a
    // toggle that ran for the same click.
    function closeDashboard() {
        hideTimer.stop();
        root.revealed = false;
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            left: true
            right: true
        }

        // No reserved space: windows keep the full screen, the panel floats.
        exclusiveZone: 0
        implicitHeight: Theme.edgeLine + Theme.panelHeight + 4
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // OnDemand rather than None: the bookmark field needs typed input,
        // but focus is only taken once the user clicks into the panel.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "quickshell-topbar"

        // The pointer counts as inside if EITHER handler sees it. Reacting to
        // each handler's own hoveredChanged was last-call-wins: once the card
        // slid over the pointer it took hover away from the hotspot, whose
        // false then started the hide timer and bounced the panel shut — a
        // permanent flicker whenever the cursor sat on the screen edge.
        readonly property bool pointerInside: hotspotHover.hovered
                                              || railHover.hovered
                                              || scrimHover.hovered
                                              || cardHover.hovered
        onPointerInsideChanged: root.syncHover(pointerInside)

        // Only this region swallows pointer input, and it only ever GROWS as
        // the two steps happen — never switches. A region that shrinks under a
        // resting pointer is the old edge-flicker bug: hover drops for a frame,
        // the hide timer starts, and the panel bounces shut.
        //
        //   idle      trigger strip
        //   rail down trigger strip + the 5px rail, full width
        //   open      + the whole panel band, full width
        //
        // Nested regions union; the two nested items collapse to 0 height when
        // their step is not active, so nothing has to be swapped out.
        mask: Region {
            item: hotspot

            Region { item: railStrip }
            Region { item: scrim }
        }

        // --- Trigger strip: top 15px, middle 10% of the screen ---
        Item {
            id: hotspot
            width: Math.round(win.width * Theme.hotspotWidthFraction)
            height: Theme.hotspotHeight
            x: Math.round((win.width - width) / 2)
            y: 0

            HoverHandler { id: hotspotHover }
            // Clicking the trigger strip does the same thing as clicking the
            // rail: by the time a click lands here the rail is already down,
            // and this strip already swallowed the click either way.
            //
            // Disabled while the pointer is on the rail, which sits INSIDE this
            // strip. Both handlers firing for one click is the bug that made
            // clicking the bar do nothing; toggleDashboard() also debounces,
            // but making only one of them live is the structural fix rather
            // than a race that happens to be caught.
            TapHandler {
                enabled: !railHover.hovered
                onTapped: root.toggleDashboard()
            }
        }

        // --- Step 1: the rail, and the thing that is clicked for step 2 ---
        // Exactly as tall as the rail is painted, so the width of screen edge
        // that stops being clickable is the width of screen edge that is
        // visibly covered — and only while the rail is actually down. 5px is a
        // fine target because the pointer cannot travel above y=0.
        Item {
            id: railStrip
            x: 0
            y: 0
            width: win.width
            height: root.railShown ? Theme.edgeLine : 0

            // cursorShape belongs on the HOVER handler: a TapHandler is only
            // `active` while the button is held, so the hand would appear on
            // press instead of on approach.
            HoverHandler {
                id: railHover
                cursorShape: Qt.PointingHandCursor
            }
            // A TapHandler rather than a MouseArea: a hover-enabled MouseArea
            // would steal hover from the handlers around it, which is the exact
            // shape of the old edge-flicker bug.
            TapHandler { onTapped: root.toggleDashboard() }
        }

        // --- Step 2: everything the open dashboard owns ---
        // FULL WIDTH, not just the card. This used to be a card-width region
        // and the gap either side of it was a trap: click the rail near the
        // screen edge and the pointer had to cross unmasked pixels to reach the
        // centred card, hover dropped, and the 320ms hide timer shut the panel
        // while you were still on your way to it.
        //
        // Its geometry is deliberately STATIC — deriving the height from the
        // animating card.y made the region collapse to nothing for the first
        // frames of the slide-in, so the pointer fell through and the panel
        // flickered. It collapses to 0 height when closed rather than being
        // switched out of the mask.
        Item {
            id: scrim
            x: 0
            y: 0
            width: win.width
            height: root.revealed ? Theme.edgeLine + Theme.panelHeight : 0

            HoverHandler { id: scrimHover }

            // Click anywhere off the card to dismiss. Disabled wherever another
            // handler owns the click: the card's own controls are on top of
            // this, and the rail/trigger already toggle — and since a tap is
            // delivered to ALL of them, an unguarded close here would race the
            // toggle and reopen the panel it just shut.
            TapHandler {
                enabled: !cardHover.hovered
                         && !railHover.hovered
                         && !hotspotHover.hovered
                onTapped: root.closeDashboard()
            }
        }

        // --- Step 1 motion: the rail slides down out of the screen edge ---
        // Same easing family as the body, just shorter: 5px travelling for the
        // body's 380ms reads as a stall rather than as motion.
        property real railOffset: root.railShown ? 0 : -(Theme.edgeLine + 2)
        Behavior on railOffset {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutExpo }
        }

        property real chromeOpacity: root.railShown ? 1.0 : 0.0
        Behavior on chromeOpacity {
            NumberAnimation {
                duration: root.railShown ? Theme.animNormal : Theme.animFast
                easing.type: Theme.easeOutQuint
            }
        }

        // --- Geometry shared by the silhouette, the mask and the content ---
        readonly property real targetBodyWidth: Math.min(Theme.panelWidth, width - 40)

        // Animates both width and height simultaneously from top-center, creating
        // a diagonal outward-and-downward expansion effect.
        property real currentBodyWidth: root.revealed ? targetBodyWidth : 0
        Behavior on currentBodyWidth {
            NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
        }

        property real bodyHeight: root.revealed ? Theme.panelHeight : 0
        Behavior on bodyHeight {
            NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
        }

        readonly property real bodyLeft: Math.round((width - currentBodyWidth) / 2)
        readonly property real bodyRight: bodyLeft + currentBodyWidth
        readonly property real bodyBottom: Theme.edgeLine + bodyHeight

        // Both radii grow with body dimensions so shape stays sane near 0.
        readonly property real filletR: Math.min(Theme.cornerFillet, Math.min(bodyHeight, currentBodyWidth / 2))
        readonly property real bottomR: Math.min(Theme.radiusPanel, Math.min(bodyHeight / 2, currentBodyWidth / 2))

        // --- Rail + panel drawn as ONE closed path ---
        // A Rectangle can't produce the concave join where the body meets the
        // rail (that needs an outward-curving corner), so the whole silhouette
        // is a single filled path: full-width rail across the top, flaring out
        // into the panel body below it.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            opacity: win.chromeOpacity
            // Rail and body are one path, so one translate carries both. It is
            // 0 whenever the dashboard is open, so this only ever moves the
            // bare rail.
            transform: Translate { y: win.railOffset }

            ShapePath {
                fillColor: Theme.panelBg
                strokeColor: Theme.panelBorder
                strokeWidth: 1

                startX: 0
                startY: 0

                PathLine { x: win.width; y: 0 }
                PathLine { x: win.width; y: Theme.edgeLine }

                // Concave scoop joining rail to body. The control point is the
                // inner corner, which is where the two tangent lines meet: that
                // makes the curve leave the rail horizontally and arrive at the
                // body edge vertically. Control at the outer corner reverses
                // both tangents and bulges outward instead.
                PathLine { x: win.bodyRight + win.filletR; y: Theme.edgeLine }
                PathQuad {
                    x: win.bodyRight
                    y: Theme.edgeLine + win.filletR
                    controlX: win.bodyRight
                    controlY: Theme.edgeLine
                }

                PathLine { x: win.bodyRight; y: win.bodyBottom - win.bottomR }
                PathQuad {
                    x: win.bodyRight - win.bottomR
                    y: win.bodyBottom
                    controlX: win.bodyRight
                    controlY: win.bodyBottom
                }

                PathLine { x: win.bodyLeft + win.bottomR; y: win.bodyBottom }
                PathQuad {
                    x: win.bodyLeft
                    y: win.bodyBottom - win.bottomR
                    controlX: win.bodyLeft
                    controlY: win.bodyBottom
                }

                // mirrored scoop on the left
                PathLine { x: win.bodyLeft; y: Theme.edgeLine + win.filletR }
                PathQuad {
                    x: win.bodyLeft - win.filletR
                    y: Theme.edgeLine
                    controlX: win.bodyLeft
                    controlY: Theme.edgeLine
                }

                PathLine { x: 0; y: Theme.edgeLine }
                PathLine { x: 0; y: 0 }
            }
        }

        // --- Panel contents, clipped to the growing body ---
        Item {
            id: card
            x: win.bodyLeft
            y: Theme.edgeLine
            width: win.currentBodyWidth
            height: win.bodyHeight
            clip: true
            opacity: root.revealed ? 1.0 : 0.0
            scale: root.revealed ? 1.0 : 0.95
            transformOrigin: Item.Top
            // Follows the rail so the content never detaches from the
            // silhouette it is drawn inside.
            transform: Translate { y: win.railOffset }

            Behavior on opacity {
                NumberAnimation { duration: root.revealed ? Theme.animNormal : Theme.animFast; easing.type: Theme.easeOutQuint }
            }

            Behavior on scale {
                NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
            }

            HoverHandler { id: cardHover }

            // Laid out centered inside the clipper, so the diagonal reveal wipes
            // the content into view out from top center.
            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.cardPadding
                width: Math.max(100, win.targetBodyWidth - Theme.cardPadding * 2)
                height: Theme.panelHeight - Theme.cardPadding * 2
                spacing: 10

                // ---- Tab bar ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: root.tabs
                        delegate: Item {
                            implicitWidth: tabCol.implicitWidth + 34
                            implicitHeight: 40

                            readonly property bool selected: index === root.tabIndex

                            Rectangle {
                                anchors.fill: parent
                                anchors.bottomMargin: 4
                                radius: Theme.radiusSmall
                                color: parent.selected ? "#14ffffff"
                                                       : (tabMouse.containsMouse ? "#0affffff" : "transparent")
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            ColumnLayout {
                                id: tabCol
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                spacing: 1

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.glyph
                                    font.pixelSize: 14
                                    color: parent.parent.selected ? Theme.textPrimary : Theme.textMuted
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    font.pixelSize: 10
                                    font.bold: parent.parent.selected
                                    color: parent.parent.selected ? Theme.textPrimary : Theme.textMuted
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                            }

                            // Active underline
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: parent.selected ? parent.width - 22 : 0
                                height: 2
                                radius: 1
                                color: Theme.accent
                                Behavior on width {
                                    NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tabIndex = index
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                // ---- Tab content ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    DashboardTab {
                        anchors.fill: parent
                        visible: root.tabIndex === 0
                        stats: root.stats
                        weather: root.weather
                        now: root.now
                        updates: root.updates
                        updatesBusy: root.updatesBusy
                        wallpapers: root.wallpapers
                        bookmarks: root.bookmarks
                        holidays: root.holidays
                        holidaysComplete: root.holidaysComplete

                        onRefreshUpdates: root.refreshUpdates()
                        onOpenTerminal: cmd => root.launchTerminal(cmd)
                        onApplyWallpaper: p => root.applyWallpaper(p)
                        onAddBookmark: (k, t) => root.addBookmark(k, t)
                        onDeleteBookmark: (k, i) => root.deleteBookmark(k, i)
                        onNeedHolidays: y => root.loadHolidays(y)
                    }

                    MediaTab {
                        anchors.fill: parent
                        visible: root.tabIndex === 1
                    }

                    PerformanceTab {
                        anchors.fill: parent
                        visible: root.tabIndex === 2
                        stats: root.stats
                        cpuHistory: root.cpuHistory
                        gpuHistory: root.gpuHistory
                        vramHistory: root.vramHistory
                        systemTempHistory: root.systemTempHistory
                        gpuTempHistory: root.gpuTempHistory
                        networkDownHistory: root.networkDownHistory
                        networkUpHistory: root.networkUpHistory
                    }

                    WorkspacesTab {
                        anchors.fill: parent
                        visible: root.tabIndex === 3
                        clients: root.clients
                        activeWs: root.activeWs
                        screenW: root.screenW
                        screenH: root.screenH

                        onSwitchRequested: wsId => {
                            root.dispatchHypr("workspace", wsId.toString());
                            root.revealed = false;
                        }
                        onFocusRequested: addr => {
                            root.dispatchHypr("focuswindow", "address:" + addr);
                            root.revealed = false;
                        }
                    }
                }
            }
        }
    }
}
