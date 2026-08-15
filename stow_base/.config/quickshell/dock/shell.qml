import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Shapes
import QtQuick.Effects

ShellRoot {
    id: root

    property bool revealed: false

    // ---- App model ---------------------------------------------------
    // `pinned` comes from pinned.json (file-watched, so the future settings
    // app just rewrites the file and the dock follows live). `clients` is the
    // hyprctl window list. The two merge into pinnedModel + extraModel:
    // pinned apps annotated with running state, then any running app that is
    // not pinned.
    property var pinned: []
    property var clients: []
    property var pinnedModel: []
    property var extraModel: []

    function rebuild() {
        var byKey = {};
        for (var i = 0; i < root.clients.length; i++) {
            var c = root.clients[i];
            if (!c || c.mapped === false)
                continue;
            var key = (c["class"] || c.initialClass || "").toLowerCase();
            // AuraLink and friends set no app_id at all; group those by title
            // so they still get a dock presence.
            if (key === "")
                key = "title:" + (c.title || "?");
            if (!byKey[key])
                byKey[key] = { windows: [], cls: c["class"] || "" };
            // Each window is kept, not just counted: the hover preview draws
            // one live tile per window and needs the title to pair it with its
            // Wayland toplevel.
            byKey[key].windows.push({ address: c.address,
                                      title: c.title || "",
                                      cls: c["class"] || "",
                                      ws: (c.workspace && c.workspace.name) || "" });
        }

        var pm = [];
        for (i = 0; i < root.pinned.length; i++) {
            var p = root.pinned[i];
            var k = (p["class"] || "").toLowerCase();
            var run = k !== "" ? byKey[k] : undefined;
            pm.push({ name: p.name || p.exec || "?",
                      exec: p.exec || "",
                      iconName: p.icon || p["class"] || "",
                      running: !!run,
                      windows: run ? run.windows : [] });
            if (run)
                delete byKey[k];
        }

        var em = [];
        for (var k2 in byKey) {
            var w = byKey[k2];
            // The window class doubles as the icon name often enough (checked
            // lookup falls back to a glyph when it doesn't).
            em.push({ name: w.cls !== "" ? w.cls : (w.windows[0].title || "window"),
                      exec: "",
                      iconName: w.cls,
                      running: true,
                      windows: w.windows });
        }
        root.pinnedModel = pm;
        root.extraModel = em;

        // Keep an open preview pointing at the refreshed entry rather than a
        // stale copy, so tiles appear/vanish as windows open and close.
        if (root.previewEntry) {
            var all = pm.concat(em);
            var found = null;
            for (i = 0; i < all.length; i++)
                if (all[i].name === root.previewEntry.name)
                    found = all[i];
            if (found && found.windows.length > 0) {
                root.previewEntry = found;
                // Arm the preview here too, not only on pointer-enter: hovering
                // an icon before the first client poll lands (or the instant an
                // app's first window maps) would otherwise leave the card
                // permanently unarmed, since no new enter event is coming.
                if (root.hoverName === found.name && !root.previewOn)
                    previewShowTimer.restart();
            } else {
                root.previewOn = false;
            }
        }
    }

    FileView {
        path: "/home/reign/.config/quickshell/dock/pinned.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text());
                root.pinned = d.pinned || [];
            } catch (e) {
                // Keep the previous list rather than blanking the dock while
                // the settings app is mid-write.
            }
            root.rebuild();
        }
    }

    Process {
        id: clientsProc
        command: ["bash", "-c", "hyprctl -j clients | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.clients = JSON.parse(data.trim());
                } catch (e) {}
                root.rebuild();
            }
        }
    }

    // Only polls while open; a hidden dock costs nothing.
    Timer {
        interval: 2000
        running: root.revealed
        repeat: true
        triggeredOnStart: true
        onTriggered: clientsProc.running = true
    }

    // ---- Actions -----------------------------------------------------
    function launch(cmd) {
        // setsid so the app outlives this shell -- a Quickshell Process is a
        // child, and restarting the dock would otherwise kill the window.
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = ["sh", "-c", "setsid " + cmd + " >/dev/null 2>&1 &"];
        p.running = true;
    }

    function focusAddress(address) {
        if (!address)
            return;
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        // NOT `hyprctl dispatch focuswindow ...`: this Hyprland is configured
        // in Lua, so dispatch arguments are parsed as Lua and the bare
        // `address:0x...` is a syntax error. `eval` takes the real Lua call.
        p.command = ["hyprctl", "eval",
                     'hl.dispatch(hl.dsp.focus({ window = "address:' + address + '" }))'];
        p.running = true;
    }

    function activate(e) {
        if (!e)
            return;
        if (e.running && e.windows.length > 0) {
            root.focusAddress(e.windows[0].address);
        } else if (e.exec) {
            root.launch(e.exec);
        }
    }

    // ---- Live previews ------------------------------------------------
    // Pairs a hyprctl client with its Wayland toplevel, which is the handle
    // ScreencopyView captures from. appId matches hyprland's class; the title
    // disambiguates between several windows of the same app, and a same-class
    // toplevel is a better fallback than nothing when a title lags behind.
    function toplevelFor(cls, title) {
        var m = ToplevelManager.toplevels;
        if (!m)
            return null;
        var want = (cls || "").toLowerCase();
        var vals = m.values;
        var fallback = null;
        for (var i = 0; i < vals.length; i++) {
            var t = vals[i];
            if ((t.appId || "").toLowerCase() !== want)
                continue;
            if (t.title === title)
                return t;
            if (!fallback)
                fallback = t;
        }
        return fallback;
    }

    property var previewEntry: null
    property real previewX: 0
    property bool previewOn: false

    Timer {
        id: previewShowTimer
        interval: 260
        repeat: false
        onTriggered: if (root.previewEntry && root.previewEntry.windows.length > 0)
                         root.previewOn = true
    }

    Timer {
        id: previewHideTimer
        // Generous on purpose: this is the grace period for the pointer
        // travelling between an icon and the card above it.
        interval: 350
        repeat: false
        onTriggered: root.previewOn = false
    }

    // Which icon the pointer is on, independent of the entry object, which is
    // replaced wholesale on every rebuild.
    property string hoverName: ""

    function hoverEnter(entry, centreX) {
        root.hoverName = entry.name;
        root.previewEntry = entry;
        root.previewX = centreX;
        root.tipText = entry.name;
        root.tipOn = true;
        previewHideTimer.stop();
        if (entry.windows.length > 0)
            previewShowTimer.restart();
        else
            root.previewOn = false;
    }

    function hoverLeave() {
        root.hoverName = "";
        root.tipOn = false;
        previewShowTimer.stop();
        // Leaving the icon does NOT mean leaving the preview: reaching for a
        // tile exits the icon while entering the card, and the icon's exit
        // arrives last. Restarting the timer unconditionally here made the
        // card close 350ms after the pointer landed on it, every time.
        if (!previewHover.hovered)
            previewHideTimer.restart();
    }

    // ---- Tooltip -----------------------------------------------------
    property string tipText: ""
    property real tipX: 0
    property bool tipOn: false

    IpcHandler {
        target: "dock"

        // open/close rather than show/hide: `qs ipc` owns the name `show`.
        function toggle(): void { hideTimer.stop(); root.revealed = !root.revealed; }
        function open(): void { hideTimer.stop(); root.revealed = true; }
        function close(): void { hideTimer.stop(); root.revealed = false; }
    }

    Timer {
        id: hideTimer
        interval: 320
        repeat: false
        onTriggered: root.revealed = false
    }

    PanelWindow {
        id: win

        anchors { left: true; right: true; bottom: true }

        exclusiveZone: 0
        // Tall enough to paint the preview card and tooltip above the body;
        // only the body (and the card, while open) is inside the input mask.
        implicitHeight: Theme.previewArea + Theme.tooltipArea
                        + Theme.panelHeight + Theme.edgeLine
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-dock"

        // The pointer counts as inside if EITHER handler sees it; reacting to
        // each handler's own hoveredChanged is last-call-wins and flickers.
        readonly property bool pointerInside: hotspotHover.hovered || dockHover.hovered
                                              || previewHover.hovered
        onPointerInsideChanged: {
            if (pointerInside) {
                hideTimer.stop();
                root.revealed = true;
            } else if (root.revealed) {
                hideTimer.restart();
            }
        }

        // Nested regions union, so the preview card becomes clickable without
        // the body's region having to grow into a screen-wide click blocker.
        // previewMask collapses to 0x0 when the card is hidden.
        mask: Region {
            item: root.revealed ? openMask : hotspot

            Region { item: previewMask }
        }

        // --- Trigger strip: bottom 15px, middle 25% of the screen ---
        Item {
            id: hotspot
            width: Math.round(win.width * Theme.hotspotWidthFraction)
            height: Theme.hotspotHeight
            x: Math.round((win.width - width) / 2)
            y: win.height - height

            HoverHandler { id: hotspotHover }
        }

        // --- Geometry shared by silhouette, mask and content ---
        readonly property real railY: height - Theme.edgeLine

        // Target width follows the model instantly (the mask must never lag
        // reality); the painted width eases after it.
        readonly property real bodyWTarget:
            (root.pinnedModel.length + root.extraModel.length) * Theme.iconSlot
            + (root.extraModel.length > 0 ? Theme.separatorWidth : 0)
            + Theme.separatorWidth
            + Theme.dockPadding * 2
        property real bodyW: bodyWTarget
        Behavior on bodyW {
            NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint }
        }

        // The body grows upward out of the rail, so it is the HEIGHT that
        // animates on reveal.
        property real bodyHeight: root.revealed ? Theme.panelHeight : 0
        Behavior on bodyHeight {
            NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
        }

        readonly property real bodyTop: railY - bodyHeight
        readonly property real bodyLeft: (width - bodyW) / 2
        readonly property real bodyRight: bodyLeft + bodyW
        // Both radii shrink with the body so the shape stays sane at height 0.
        readonly property real filletR: Math.min(Theme.cornerFillet, bodyHeight)
        readonly property real cornerR: Math.min(Theme.radiusPanel, bodyHeight / 2)

        // Input region while open. Height/y are deliberately STATIC (deriving
        // them from the animating body collapses the region mid-slide and the
        // pointer falls through); width tracks the un-animated target.
        Item {
            id: openMask
            x: (win.width - win.bodyWTarget) / 2 - Theme.cornerFillet
            y: win.height - Theme.edgeLine - Theme.panelHeight
            width: win.bodyWTarget + Theme.cornerFillet * 2
            height: Theme.panelHeight + Theme.edgeLine
        }

        // --- Preview card geometry (shared by the card and its mask) ---
        readonly property int previewTiles:
            root.previewEntry ? Math.min(root.previewEntry.windows.length,
                                         Theme.previewMaxTiles) : 0
        readonly property real previewW:
            previewTiles * (Theme.previewTileW + Theme.previewSpacing)
            - Theme.previewSpacing + Theme.previewPadding * 2
        readonly property real previewBottom:
            height - Theme.edgeLine - Theme.panelHeight - 8
        readonly property real previewCardX:
            Math.max(6, Math.min(width - previewW - 6, root.previewX - previewW / 2))
        readonly property real previewCardY: previewBottom - Theme.previewCardH

        // Collapses to nothing when hidden, so the union above contributes no
        // clickable area. Static while open -- deriving it from the card's pop
        // animation would let the pointer fall through mid-transition.
        Item {
            id: previewMask
            x: win.previewCardX
            y: win.previewCardY
            width: root.previewOn ? win.previewW : 0
            height: root.previewOn ? Theme.previewCardH + 8 : 0
        }

        // --- Rail + body drawn as ONE closed path ---
        // A Rectangle cannot produce the concave join where the body meets the
        // rail, so the whole silhouette is a single filled path: a full-width
        // rail along the bottom flaring up into the centred body.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true

            ShapePath {
                fillColor: Theme.panelBg
                strokeColor: Theme.panelBorder
                strokeWidth: 1

                startX: 0
                startY: win.height

                PathLine { x: 0; y: win.railY }
                PathLine { x: win.bodyLeft - win.filletR; y: win.railY }

                // Concave scoop joining rail to body. The control point sits
                // at the inner corner, where the two tangent lines meet: the
                // curve leaves the rail horizontally and arrives at the body
                // edge vertically. Control at the outer corner reverses both
                // tangents and bulges outward instead.
                PathQuad {
                    x: win.bodyLeft
                    y: win.railY - win.filletR
                    controlX: win.bodyLeft
                    controlY: win.railY
                }

                PathLine { x: win.bodyLeft; y: win.bodyTop + win.cornerR }
                PathQuad {
                    x: win.bodyLeft + win.cornerR
                    y: win.bodyTop
                    controlX: win.bodyLeft
                    controlY: win.bodyTop
                }

                PathLine { x: win.bodyRight - win.cornerR; y: win.bodyTop }
                PathQuad {
                    x: win.bodyRight
                    y: win.bodyTop + win.cornerR
                    controlX: win.bodyRight
                    controlY: win.bodyTop
                }

                PathLine { x: win.bodyRight; y: win.railY - win.filletR }
                // mirrored scoop on the right
                PathQuad {
                    x: win.bodyRight + win.filletR
                    y: win.railY
                    controlX: win.bodyRight
                    controlY: win.railY
                }

                PathLine { x: win.width; y: win.railY }
                PathLine { x: win.width; y: win.height }
                PathLine { x: 0; y: win.height }
            }
        }

        // --- Live preview card ---
        // One tile per window of the hovered app. Capture is only live while
        // the card is up: a ScreencopyView with live:true is a real per-frame
        // GPU copy of that window, so leaving them all running would cost more
        // than the dock itself.
        // Hover zone = card + the gap down to the dock body. Without the gap
        // the pointer travelling from icon to card crosses a strip that is
        // inside the input mask but under no hover handler, which starts both
        // hide timers and snatches the card away mid-reach.
        Item {
            id: previewZone

            x: win.previewCardX
            y: win.previewCardY
            width: win.previewW
            height: Theme.previewCardH + 8
            visible: previewCard.opacity > 0.01

            Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }
            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutQuint } }

            HoverHandler {
                id: previewHover
                onHoveredChanged: {
                    if (hovered)
                        previewHideTimer.stop();
                    else
                        previewHideTimer.restart();
                }
            }

        Rectangle {
            id: previewCard

            width: parent.width
            height: Theme.previewCardH
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.color: Theme.panelBorder
            border.width: 1

            visible: opacity > 0.01
            opacity: root.previewOn ? 1.0 : 0.0
            // Grows out of the icon it belongs to rather than fading in place.
            scale: root.previewOn ? 1.0 : 0.86
            transformOrigin: Item.Bottom

            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easeOutQuint } }
            Behavior on scale {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 0.9 }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.previewSpacing

                Repeater {
                    model: root.previewOn && root.previewEntry
                           ? root.previewEntry.windows.slice(0, Theme.previewMaxTiles)
                           : []

                    delegate: Column {
                        spacing: 3

                        Rectangle {
                            width: Theme.previewTileW
                            height: Theme.previewTileH
                            radius: Theme.radiusSmall
                            color: "#0c0c10"
                            border.color: tileMouse.containsMouse ? Theme.accent : Theme.panelBorder
                            border.width: 1
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            ScreencopyView {
                                id: shot
                                anchors.centerIn: parent
                                // constraintSize fits the capture inside the
                                // tile preserving aspect, instead of stretching
                                // a 16:9 window into the tile's box.
                                constraintSize: Qt.size(Theme.previewTileW - 4,
                                                        Theme.previewTileH - 4)
                                captureSource: root.toplevelFor(modelData.cls, modelData.title)
                                live: root.previewOn
                                paintCursor: false
                            }

                            // Shown until the first frame lands, and for windows
                            // the compositor won't hand us (an unmapped window
                            // on another workspace has nothing to copy).
                            Text {
                                anchors.centerIn: parent
                                text: "󰖯"
                                font.pixelSize: 26
                                color: Theme.textFaint
                                visible: !shot.hasContent
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                text: modelData.ws
                                font.pixelSize: 9
                                color: Theme.textMuted
                                visible: modelData.ws !== ""
                            }

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.focusAddress(modelData.address);
                                    root.previewOn = false;
                                }
                            }
                        }

                        Text {
                            width: Theme.previewTileW
                            height: Theme.previewLabel
                            text: modelData.title || "—"
                            font.pixelSize: 9
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
        }

        // --- Tooltip, floating above the body ---
        // Outside the clipper and outside the input mask: a transient overlay
        // must never block a click or hold the dock open.
        Text {
            id: tooltip
            text: root.tipText
            font.pixelSize: 12
            font.bold: true
            color: Theme.textPrimary
            // The card labels each window itself, so the plain name tooltip
            // would just be duplication once previews are up.
            opacity: root.tipOn && root.revealed && !root.previewOn ? 0.9 : 0.0

            x: Math.max(6, Math.min(win.width - width - 6, root.tipX - width / 2))
            y: win.height - Theme.edgeLine - Theme.panelHeight - height - 8

            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        // --- Icon row, clipped to the growing body ---
        Item {
            id: body
            x: win.bodyLeft
            y: win.bodyTop
            width: win.bodyW
            height: win.bodyHeight
            clip: true
            opacity: root.revealed ? 1.0 : 0.0

            Behavior on opacity { NumberAnimation { duration: 180 } }

            HoverHandler { id: dockHover }

            // Anchored to the BOTTOM of the clipper: the bottom edge sits on
            // the rail and stays fixed while the top edge rises, so the icons
            // are wiped into view instead of re-laid-out every frame.
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dockPadding
                x: Theme.dockPadding
                spacing: 0

                Repeater {
                    model: root.pinnedModel
                    delegate: DockIcon {
                        entry: modelData
                        onActivated: root.activate(modelData)
                        onHoverEntered: {
                            var cx = mapToItem(null, width / 2, 0).x;
                            root.tipX = cx;
                            root.hoverEnter(modelData, cx);
                        }
                        onHoverLeft: root.hoverLeave()
                    }
                }

                Item {
                    width: Theme.separatorWidth
                    height: Theme.iconSlot
                    visible: root.extraModel.length > 0

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: Theme.iconSlot - 20
                        color: Theme.textFaint
                    }
                }

                Repeater {
                    model: root.extraModel
                    delegate: DockIcon {
                        entry: modelData
                        onActivated: root.activate(modelData)
                        onHoverEntered: {
                            var cx = mapToItem(null, width / 2, 0).x;
                            root.tipX = cx;
                            root.hoverEnter(modelData, cx);
                        }
                        onHoverLeft: root.hoverLeave()
                    }
                }

                Item {
                    width: Theme.separatorWidth
                    height: Theme.iconSlot

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: Theme.iconSlot - 20
                        color: Theme.textFaint
                    }
                }
            }
        }
    }
}
