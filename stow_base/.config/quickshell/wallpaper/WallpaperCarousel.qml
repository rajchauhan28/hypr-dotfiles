import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Fullscreen wallpaper carousel: a row of skewed cards over a blurred copy of
// the highlighted wallpaper. ← → (or h l, or the wheel) browse, Enter or a
// click on the centre card applies, Esc or a click on the backdrop closes.
// Applying goes through walllust-cli, the same daemon wallpaper_switcher.sh
// drives, so palette regeneration happens exactly as it does on rotation.
//
// qs ipc call wallpaper {toggle,open,close,next,prev}     (Super+W)
Scope {
    id: root

    readonly property string lister: Quickshell.env("HOME") + "/.config/quickshell/wallpaper/list.py"

    property bool shown: false
    property var items: []
    property string current: ""
    property string _lastJson: ""
    property bool _centreOnLoad: false

    readonly property var selected: (view.currentIndex >= 0 && view.currentIndex < items.length)
                                    ? items[view.currentIndex] : null

    function indexOfPath(p) {
        for (var i = 0; i < root.items.length; i++)
            if (root.items[i].path === p)
                return i;
        return -1;
    }

    function centreOnCurrent() {
        var i = root.indexOfPath(root.current);
        view.currentIndex = i >= 0 ? i : 0;
        view.snap();
    }

    function open() {
        // Show the cached model straight away; the refresh lands a moment
        // later and only rebuilds the model if something actually changed.
        root._centreOnLoad = true;
        listProc.running = true;
        root.centreOnCurrent();
        root.shown = true;
    }
    function close() { root.shown = false; }
    function toggle() { if (root.shown) root.close(); else root.open(); }

    function step(d) {
        if (!root.shown)
            root.open();
        if (root.items.length > 0)
            view.currentIndex = Math.max(0, Math.min(root.items.length - 1, view.currentIndex + d));
    }

    function apply(i) {
        var it = root.items[i];
        if (!it)
            return;
        Quickshell.execDetached(["walllust-cli", "set", it.path]);
        root.current = it.path;
        root.close();
    }

    Process {
        id: listProc
        command: ["python3", "-I", root.lister]
        stdout: StdioCollector {
            onStreamFinished: {
                var d;
                try { d = JSON.parse(text); } catch (e) { return; }
                root.current = d.current || "";
                if (text !== root._lastJson) {
                    var keep = root.selected ? root.selected.path : "";
                    root._lastJson = text;
                    root.items = d.items || [];
                    var j = root.indexOfPath(keep);
                    if (!root._centreOnLoad && j >= 0)
                        view.currentIndex = j;
                    view.snap();
                }
                if (root._centreOnLoad) {
                    root._centreOnLoad = false;
                    root.centreOnCurrent();
                }
            }
        }
    }

    // Build the thumbnail cache at login so the first open is instant.
    Component.onCompleted: listProc.running = true

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle(); }
        function open(): void   { root.open(); }
        function close(): void  { root.close(); }
        function next(): void   { root.step(1); }
        function prev(): void   { root.step(-1); }
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root.shown || content.opacity > 0.01

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-wallpaper"

        Item {
            id: content
            anchors.fill: parent
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            // --- Backdrop: the highlighted wallpaper, blurred and dimmed ----
            Image {
                id: backdrop
                anchors.fill: parent
                source: root.selected && root.selected.thumb ? "file://" + root.selected.thumb : ""
                fillMode: Image.PreserveAspectCrop
                // Synchronous on purpose: a 640px thumb decodes in a few ms, and
                // an async swap blanks the backdrop for a frame on every step.
                asynchronous: false
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: backdrop
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: 1.0
            }
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.55
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            // Trackpads send many small deltas; step once per 120 units.
            WheelHandler {
                property real acc: 0
                onWheel: (ev) => {
                    acc += ev.angleDelta.y !== 0 ? -ev.angleDelta.y : ev.angleDelta.x;
                    while (Math.abs(acc) >= 120) {
                        root.step(acc > 0 ? 1 : -1);
                        acc -= acc > 0 ? 120 : -120;
                    }
                }
            }

            Item {
                id: keys
                focus: true
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Escape) root.close();
                    else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.step(-1);
                    else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) root.step(1);
                    else if (e.key === Qt.Key_Home) view.currentIndex = 0;
                    else if (e.key === Qt.Key_End) view.currentIndex = root.items.length - 1;
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.apply(view.currentIndex);
                    else return;
                    e.accepted = true;
                }
            }

            Connections {
                target: root
                function onShownChanged() {
                    if (root.shown)
                        keys.forceActiveFocus();
                }
            }

            // --- The carousel ---------------------------------------------
            ListView {
                id: view

                readonly property real hC: win.height * Theme.currentHeight
                readonly property real hS: win.height * Theme.sideHeight
                readonly property real wC: hC * Theme.currentAspect
                readonly property real wS: hS * Theme.sideAspect

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: hC + 20

                orientation: ListView.Horizontal
                spacing: Theme.spacing
                model: root.items
                // Browsing is keys, wheel and clicks; a non-interactive view
                // also lets clicks between cards fall through to the backdrop.
                interactive: false
                cacheBuffer: Math.round(width * 2)

                // Scrolling is driven by hand. ListView's highlight ranges
                // re-pick the current item whenever a card's animated width
                // moves its neighbours, which walked the selection off to
                // card 0 on every open.
                highlightRangeMode: ListView.NoHighlightRange
                highlightFollowsCurrentItem: false

                // Room either side so the first and last cards can sit centred.
                header: Item { width: view.width / 2; height: 1 }
                footer: Item { width: view.width / 2; height: 1 }

                // Every card before the current one is side-width, so the
                // current card's final x is known up front, without waiting
                // for the width animations to settle.
                readonly property real firstX: headerItem ? headerItem.x + headerItem.width : 0
                readonly property real centreX: firstX + currentIndex * (wS + spacing) + wC / 2 - width / 2

                function snap() {
                    slide.stop();
                    contentX = centreX;
                }

                NumberAnimation {
                    id: slide
                    target: view
                    property: "contentX"
                    duration: Theme.animMs
                    easing.type: Easing.OutCubic
                }

                onCentreXChanged: {
                    slide.stop();
                    slide.from = contentX;
                    slide.to = centreX;
                    slide.start();
                }
                // The window has no width until the compositor maps it.
                onWidthChanged: snap()

                delegate: Item {
                    id: card

                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property real k: Theme.skew

                    width: isCurrent ? view.wC : view.wS
                    height: view.height
                    Behavior on width { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }

                    // The parallelogram. Sheared about its vertical centre so
                    // the top edge leans right and the bottom left; clip makes
                    // the shear the visible outline.
                    Item {
                        id: frame
                        anchors.centerIn: parent
                        width: parent.width
                        height: card.isCurrent ? view.hC : view.hS
                        Behavior on height { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }
                        clip: true
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -card.k, 0, card.k * frame.height / 2,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        // Counter-sheared so the picture stays upright inside
                        // the slanted frame; widened by k*h to cover both
                        // overhanging corners.
                        Image {
                            width: frame.width + card.k * frame.height
                            height: frame.height
                            x: -card.k * frame.height / 2
                            source: card.modelData.thumb ? "file://" + card.modelData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            transform: Matrix4x4 {
                                matrix: Qt.matrix4x4(1, card.k, 0, -card.k * frame.height / 2,
                                                     0, 1, 0, 0,
                                                     0, 0, 1, 0,
                                                     0, 0, 0, 1)
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: card.isCurrent ? 0 : 0.45
                            Behavior on opacity { NumberAnimation { duration: Theme.animMs } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: card.isCurrent ? 2 : 1
                            border.color: card.isCurrent ? Theme.accent : "#26ffffff"
                        }
                    }

                    // Video badge, unsheared, tucked inside the top-left corner.
                    Rectangle {
                        visible: card.modelData.video
                        x: card.k * frame.height / 2 + 6
                        y: frame.y + 8
                        width: 26
                        height: 20
                        radius: 5
                        color: "#99000000"
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: "#ffffff"
                            font.pixelSize: 11
                        }
                    }

                    // Marks the wallpaper that is on screen right now.
                    Rectangle {
                        visible: card.modelData.path === root.current
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: frame.y + frame.height + 8
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.centerIn: parent
                        width: parent.width
                        height: frame.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.isCurrent)
                                root.apply(card.index);
                            else
                                view.currentIndex = card.index;
                        }
                    }
                }
            }

            // --- Caption ----------------------------------------------------
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: view.y + view.height + 28
                spacing: 6
                visible: root.items.length > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, win.width * 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: root.selected ? root.selected.name : ""
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (view.currentIndex + 1) + " / " + root.items.length
                          + "     ← →  browse   ·   Enter  apply   ·   Esc  close"
                    color: "#b3ffffff"
                    font.pixelSize: 12
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: listProc.running ? "Building thumbnails…" : "No wallpapers found"
                color: "#ffffff"
                font.pixelSize: 16
            }
        }
    }
}
