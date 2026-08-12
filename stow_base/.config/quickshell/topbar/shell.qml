import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Shapes

ShellRoot {
    id: root

    // ---- Reveal state -------------------------------------------------
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

    onWantMediaChanged: MediaService.active = root.wantMedia
    onTabIndexChanged: {
        MediaService.wantVolume = (root.tabIndex === 1);
        // Spectrum runs whenever the topbar panel is open to feed circumference waves
        MediaService.wantSpectrum = revealed;
    }

    // Everything below is gated on `revealed` so a hidden panel costs nothing.
    onRevealedChanged: {
        MediaService.active = root.wantMedia;
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
        command: ["/home/reign/.config/quickshell/topbar/updates.sh"]
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
            "/home/reign/.config/quickshell/topbar/wallpapers.py", "set", path];
        wallpaperSetProc.running = true;
    }

    Process {
        id: wallpapersProc
        running: true
        command: ["python3", "/home/reign/.config/quickshell/topbar/wallpapers.py", "list"]
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
            "/home/reign/.config/quickshell/topbar/calendar_store.py",
            "add", dateKey, text];
        bookmarkWrite.running = true;
    }

    function deleteBookmark(dateKey, idx) {
        bookmarkWrite.command = ["python3",
            "/home/reign/.config/quickshell/topbar/calendar_store.py",
            "delete", dateKey, idx.toString()];
        bookmarkWrite.running = true;
    }

    function loadHolidays(year) {
        if (year === root.holidayYear)
            return;
        root.holidayYear = year;
        holidaysProc.command = ["python3",
            "/home/reign/.config/quickshell/topbar/holidays_in.py", year.toString()];
        holidaysProc.running = true;
    }

    Process {
        id: bookmarksProc
        running: true
        command: ["python3", "/home/reign/.config/quickshell/topbar/calendar_store.py", "list"]
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
        command: ["python3", "/home/reign/.config/quickshell/topbar/sysinfo.py"]
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
        p.command = ["/home/reign/.config/quickshell/overview/hyprctl-compat.sh", cmd, arg];
        p.running = true;
    }

    // Lets a keybind pin the panel open without using the hotspot:
    //   qs -c topbar ipc call panel toggle
    IpcHandler {
        target: "panel"

        function toggle(): void {
            hideTimer.stop();
            root.revealed = !root.revealed;
        }
        // Named open/close rather than show/hide: `qs ipc` has its own `show`
        // subcommand, and the CLI swallows the name before it reaches us.
        function open(): void {
            hideTimer.stop();
            root.revealed = true;
        }
        function close(): void {
            hideTimer.stop();
            root.revealed = false;
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
        onTriggered: root.revealed = false
    }

    function syncHover(hovered) {
        if (hovered) {
            hideTimer.stop();
            root.revealed = true;
        } else if (root.revealed) {
            hideTimer.restart();
        }
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
        readonly property bool pointerInside: hotspotHover.hovered || cardHover.hovered
        onPointerInsideChanged: root.syncHover(pointerInside)

        // Only this region swallows pointer input. Collapsed that is the
        // 15px x 10% strip; revealed it also covers the panel and the gap
        // above it so the pointer never falls through mid-travel.
        mask: Region {
            item: root.revealed ? openMask : hotspot
        }

        // --- Trigger strip: top 15px, middle 10% of the screen ---
        Item {
            id: hotspot
            width: Math.round(win.width * Theme.hotspotWidthFraction)
            height: Theme.hotspotHeight
            x: Math.round((win.width - width) / 2)
            y: 0

            HoverHandler { id: hotspotHover }
        }

        // Invisible input region used while open. Its geometry is deliberately
        // STATIC — deriving the height from the animating card.y made the
        // region collapse to nothing for the first frames of the slide-in, so
        // the pointer fell through, hover dropped, and the panel flickered.
        Item {
            id: openMask
            // Widened by the fillet radius: the scoops paint that far past the
            // body's edges, and painted-but-unmasked pixels would not hold the
            // panel open when hovered.
            x: Math.round((win.width - win.targetBodyWidth) / 2) - Theme.cornerFillet
            y: 0
            width: win.targetBodyWidth + Theme.cornerFillet * 2
            height: Theme.edgeLine + Theme.panelHeight
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
