//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "search.js" as Search

// Replacement for `walker` + `elephant`.
//
// Four modes share one panel because the chrome, the keyboard handling and
// the ranking are identical between them; only the candidate source and the
// activation differ. Splitting them into separate windows would mean four
// copies of the fiddly parts.
//
//   apps      DesktopEntries, native to Quickshell -- no daemon at all.
//   clipboard cliphist, which owns the history and the image blobs.
//   files     plocate + a live fd pass, see filesearch.sh.
//   dmenu     stdin from a script, so display_switcher.sh and gpu_switcher.sh
//             keep working after walker goes.
Scope {
    id: root

    property bool opened: false
    property string mode: "apps"
    property string query: ""
    property int selected: 0

    // Ranked rows, each { label, sublabel, icon, image, payload }.
    property var results: []

    // Frecency store, keyed by the same id the ranker sees.
    property var stats: ({})

    // --- dmenu plumbing ------------------------------------------------
    // The shim blocks on a FIFO. Every exit path from dmenu mode MUST write
    // to it exactly once, including cancel, or the calling script hangs
    // forever holding the user's keybind.
    property string dmenuReplyPath: ""
    property bool dmenuAnswered: true
    property string promptOverride: ""

    readonly property string prompt: {
        if (root.promptOverride !== "")
            return root.promptOverride;
        if (root.mode === "clipboard")
            return "Clipboard";
        if (root.mode === "files")
            return "Files";
        return "Search";
    }

    // ------------------------------------------------------------------
    // Frecency store. Mirrors the dock's pinned.json contract: the repo ships
    // frecency.json.default, this file is per-user state and gitignored.
    FileView {
        id: statsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/launcher/frecency.json"
        watchChanges: false
        onLoaded: {
            try {
                root.stats = JSON.parse(text()) || ({});
            } catch (e) {
                root.stats = ({});
            }
        }
        onLoadFailed: root.stats = ({})
    }

    function bumpFrecency(id) {
        if (!id)
            return;
        var s = root.stats;
        var cur = s[id] || { count: 0, last: 0 };
        cur.count = (cur.count || 0) + 1;
        cur.last = Date.now();
        s[id] = cur;
        root.stats = s;
        statsFile.setText(JSON.stringify(s));
    }

    // ------------------------------------------------------------------
    // Candidate sources.

    // Apps come straight from Quickshell -- no elephant, no socket, no cache
    // to go stale. noDisplay entries are the ones .desktop files explicitly
    // mark as not-for-menus, so honouring it is what keeps the list clean.
    function appEntries() {
        var out = [];
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i];
            if (a.noDisplay)
                continue;
            out.push({
                id: "app:" + a.id,
                label: a.name,
                sublabel: a.genericName || a.comment || "",
                icon: a.icon ? Quickshell.iconPath(a.icon, true) : "",
                image: "",
                kind: "app",
                payload: a,
                fields: [
                    { text: a.name, weight: 1.0 },
                    { text: a.genericName || "", weight: 0.7 },
                    { text: (a.keywords || []).join(" "), weight: 0.6 },
                    { text: a.comment || "", weight: 0.4 }
                ]
            });
        }
        return out;
    }

    property var clipboardEntries: []
    property var dmenuEntries: []

    // files mode keeps the two stages apart so the instant half can paint
    // while the live walk is still running. Each carries the query it was
    // launched for: a walk that lands after the user has typed on is stale and
    // must be dropped, or the list would flick back to older results.
    property var fileEntriesFast: []
    property var fileEntriesSlow: []
    property string fileQueryFast: ""
    property string fileQuerySlow: ""

    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line)
                        continue;
                    // cliphist emits "<id>\t<preview>". Splitting on the first
                    // tab only, because the payload may well contain tabs.
                    var tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    var id = line.substring(0, tab);
                    var preview = line.substring(tab + 1);

                    // Binary entries look like
                    //   "[[ binary data 72 KiB png 584x317 ]]"
                    // which carries the format and the dimensions, so the kind
                    // of preview is known without decoding anything.
                    var bin = preview.match(/^\[\[ binary data (\S+ \S+) (\S+) (\S+) \]\]$/);
                    var fmt = bin ? bin[2] : "";
                    var label = bin ? (bin[2].toUpperCase() + "  " + bin[3]) : preview;
                    var sub = bin ? bin[1] : "";

                    out.push({
                        id: "clip:" + id,
                        label: label,
                        sublabel: sub,
                        // Binary entries get their icon replaced by a real
                        // preview once clippreview.sh reports back; text
                        // entries keep this one.
                        icon: Quickshell.iconPath(bin ? "image-x-generic" : "edit-paste", true),
                        fmt: fmt,
                        // The unmodified entry text: clippreview.sh needs it to
                        // recognise a file path or file:// URI. `label` has
                        // already been prettified for binary entries.
                        rawText: preview,
                        kind: "clip",
                        payload: id,
                        // Rank clipboard purely on the text; recency is already
                        // encoded by cliphist's own ordering, preserved via bias.
                        bias: (lines.length - i) * 2,
                        fields: [{ text: preview, weight: 1.0 }]
                    });
                }
                root.clipboardEntries = out;
                root.rebuild();
                root.resolvePreviews(out);
            }
        }
    }

    // id -> { kind, payload }, filled in asynchronously after the list renders.
    // Kept as a separate map rather than baked into the entries so a preview
    // arriving does not require re-ranking and re-instantiating every row.
    property var clipPreviews: ({})

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length < 3)
                        continue;
                    map[parts[0]] = { kind: parts[1], payload: parts[2] };
                }
                root.clipPreviews = map;
            }
        }
    }

    function resolvePreviews(entries) {
        root.clipPreviews = ({});
        if (!entries.length)
            return;

        // One process for the whole visible page. Per-row processes made
        // scrolling stutter, and decoding the entire history would be wasted
        // work on entries nobody scrolls to.
        var lines = [];
        for (var i = 0; i < entries.length && i < Theme.maxResults; i++) {
            var e = entries[i];
            // "-" and never an empty field: tab is IFS whitespace, so `read`
            // collapses consecutive tabs and an empty column would silently
            // shift the text into the format slot.
            var fmt = e.fmt ? e.fmt : "-";
            lines.push(e.payload + "\t" + fmt + "\t" + e.rawText.replace(/[\t\n]/g, " "));
        }

        previewProc.running = false;
        previewProc.command = ["sh", "-c",
            "printf '%s' \"$2\" | \"$1\"",
            "sh",
            Quickshell.env("HOME") + "/.config/quickshell/launcher/clippreview.sh",
            lines.join("\n") + "\n"];
        previewProc.running = true;
    }

    function parseFileLines(txt, biasBase) {
        var out = [];
        var lines = txt.split("\n");
        for (var i = 0; i < lines.length && i < 300; i++) {
            var f = lines[i];
            if (!f)
                continue;
            var slash = f.lastIndexOf("/");
            var base = slash >= 0 ? f.substring(slash + 1) : f;
            var dir = slash >= 0 ? f.substring(0, slash) : "";
            out.push({
                id: "file:" + f,
                label: base,
                sublabel: dir,
                icon: Quickshell.iconPath("text-x-generic", true),
                image: "",
                kind: "file",
                payload: f,
                // Preserve each source's own ordering as a tiebreak.
                bias: biasBase + (300 - i),
                fields: [
                    { text: base, weight: 1.0 },
                    { text: f, weight: 0.5 }
                ]
            });
        }
        return out;
    }

    Process {
        id: filesFastProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.fileQueryFast !== root.query)
                    return;
                root.fileEntriesFast = root.parseFileLines(text, 0);
                root.rebuild();
            }
        }
    }

    Process {
        id: filesSlowProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.fileQuerySlow !== root.query)
                    return;
                // Live hits outrank indexed ones at equal match quality: a file
                // new enough to be missing from the index is usually the one
                // just been working on.
                root.fileEntriesSlow = root.parseFileLines(text, 400);
                root.rebuild();
            }
        }
    }

    // Debounced so a fast typist does not spawn a search per keystroke.
    Timer {
        id: fileDebounce
        interval: 140
        repeat: false
        onTriggered: {
            if (root.query.length < 2) {
                root.fileEntriesFast = [];
                root.fileEntriesSlow = [];
                root.rebuild();
                return;
            }

            var script = Quickshell.env("HOME") + "/.config/quickshell/launcher/filesearch.sh";

            root.fileQueryFast = root.query;
            filesFastProc.running = false;
            filesFastProc.command = ["sh", script, "fast", root.query];
            filesFastProc.running = true;

            root.fileQuerySlow = root.query;
            filesSlowProc.running = false;
            filesSlowProc.command = ["sh", script, "slow", root.query];
            filesSlowProc.running = true;
        }
    }

    // ------------------------------------------------------------------
    function currentEntries() {
        if (root.mode === "clipboard")
            return root.clipboardEntries;
        if (root.mode === "files") {
            // Indexed hits first, then the live ones the index could not know
            // about. Both sources routinely return the same path.
            var merged = root.fileEntriesFast.slice();
            var seen = {};
            for (var i = 0; i < merged.length; i++)
                seen[merged[i].id] = true;
            for (var j = 0; j < root.fileEntriesSlow.length; j++) {
                var e = root.fileEntriesSlow[j];
                if (!seen[e.id])
                    merged.push(e);
            }
            return merged;
        }
        if (root.mode === "dmenu")
            return root.dmenuEntries;
        return root.appEntries();
    }

    function rebuild() {
        var ranked = Search.rank(currentEntries(), root.query, root.stats, Date.now());
        var out = [];
        for (var i = 0; i < ranked.length && i < Theme.maxResults; i++)
            out.push(ranked[i].entry);
        root.results = out;
        root.selected = 0;
    }

    onQueryChanged: {
        if (root.mode === "files")
            fileDebounce.restart();
        else
            rebuild();
    }

    // ------------------------------------------------------------------
    // Activation.
    function activate(entry) {
        if (!entry)
            return;

        if (entry.kind === "dmenu") {
            answerDmenu(entry.payload);
            close();
            return;
        }

        bumpFrecency(entry.id);

        if (entry.kind === "app") {
            entry.payload.execute();
        } else if (entry.kind === "clip") {
            // decode | wl-copy keeps binary payloads intact; routing the bytes
            // through QML would corrupt anything non-UTF-8.
            Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.payload]);
        } else if (entry.kind === "file") {
            Quickshell.execDetached(["xdg-open", entry.payload]);
        }
        close();
    }

    function answerDmenu(selection) {
        if (root.dmenuAnswered || root.dmenuReplyPath === "")
            return;
        root.dmenuAnswered = true;
        // printf via argv, never interpolated into the shell string, so a
        // menu label containing quotes or $ cannot break out.
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$2\" > \"$1\"", "sh", root.dmenuReplyPath, selection || ""]);
        root.dmenuReplyPath = "";
    }

    function openMode(m) {
        root.mode = m;
        root.query = "";
        root.promptOverride = "";
        root.opened = true;

        if (m === "clipboard") {
            root.clipboardEntries = [];
            clipProc.running = false;
            clipProc.running = true;
        } else if (m === "files") {
            root.fileEntriesFast = [];
            root.fileEntriesSlow = [];
            root.fileQueryFast = "";
            root.fileQuerySlow = "";
        }
        rebuild();
    }

    function close() {
        // Cancelling a dmenu still owes the caller an answer.
        answerDmenu("");
        root.opened = false;
        root.query = "";
        root.results = [];
        root.promptOverride = "";
        root.mode = "apps";
    }

    IpcHandler {
        target: "launcher"

        // open/close rather than show/hide: `qs ipc` owns the name `show`.
        function apps(): void { root.openMode("apps"); }
        function clipboard(): void { root.openMode("clipboard"); }
        function files(): void { root.openMode("files"); }
        function close(): void { root.close(); }
        function toggle(): void {
            if (root.opened)
                root.close();
            else
                root.openMode("apps");
        }

        // Called by ~/.local/bin/qs-dmenu. itemsPath is a plain file, one
        // option per line; replyPath is a FIFO the shim is already blocked on.
        function dmenu(itemsPath: string, promptText: string, replyPath: string): void {
            root.dmenuReplyPath = replyPath;
            root.dmenuAnswered = false;
            root.promptOverride = promptText;
            root.mode = "dmenu";
            root.query = "";
            dmenuItemsFile.path = itemsPath;
            dmenuItemsFile.reload();
            root.opened = true;
        }
    }

    FileView {
        id: dmenuItemsFile
        watchChanges: false
        onLoaded: {
            var out = [];
            var lines = text().split("\n");
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i];
                if (!l)
                    continue;
                out.push({
                    id: "dmenu:" + l,
                    label: l,
                    sublabel: "",
                    icon: "",
                    image: "",
                    kind: "dmenu",
                    payload: l,
                    // Scripts build these lists in a deliberate order; with no
                    // query typed it must survive intact.
                    bias: (lines.length - i) * 1000,
                    fields: [{ text: l, weight: 1.0 }]
                });
            }
            root.dmenuEntries = out;
            root.rebuild();
        }
        onLoadFailed: {
            root.dmenuEntries = [];
            root.rebuild();
        }
    }

    // ==================================================================
    PanelWindow {
        id: win

        visible: root.opened

        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive only while actually open -- the window is destroyed
        // otherwise, but being explicit keeps the intent readable.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"

        // Reset on every reveal, not just at construction. The window object
        // outlives a close, so a Component.onCompleted focus grab only ever
        // fires once per shell lifetime -- after that the keystrokes go to
        // whatever was focused before, and the previous query is still sitting
        // in the field. Both have to be redone each time the surface appears.
        onVisibleChanged: {
            if (visible) {
                input.text = "";
                input.forceActiveFocus();
            }
        }

        // Click-off to dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            anchors.fill: parent
            color: "#73000000"
        }

        Rectangle {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.22)
            width: Theme.panelWidth
            radius: Theme.radiusPanel
            color: Theme.panelBg
            border.color: Theme.panelBorder
            border.width: 1
            clip: true

            height: searchRow.height + (list.count > 0 ? Math.min(list.contentHeight, Theme.maxListHeight) + Theme.cardPadding : 0)

            Behavior on height {
                NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutExpo }
            }

            // Swallow clicks so the dismiss MouseArea behind only fires
            // outside the card.
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            // --- Search row -------------------------------------------
            // The input sits in its own well rather than floating on the panel
            // background: it is the same card-inside-a-panel treatment the
            // topbar dashboard and the settings app use, and it gives the
            // caret somewhere to live once the result list is empty.
            Item {
                id: searchRow
                width: parent.width
                height: Theme.cardPadding * 2 + Theme.fieldHeight

                Rectangle {
                    id: field
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    radius: Theme.radiusField
                    color: Theme.cardAlt
                    border.width: 1
                    // Focus is all but permanent here, so the strong border is
                    // the resting state; it still dims if focus is ever lost.
                    border.color: input.activeFocus ? Theme.borderStrong : Theme.border

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.animFast }
                    }
                }

                // Mode chip. "Search" / "Clipboard" / "Files" was previously
                // plain muted text that read as part of the placeholder; as a
                // chip it is unmistakably a label for the mode you are in.
                Rectangle {
                    id: promptChip
                    anchors.verticalCenter: field.verticalCenter
                    x: field.x + 8
                    height: 24
                    width: promptLabel.implicitWidth + 18
                    radius: Theme.radiusChip
                    color: Theme.rowSelected

                    Text {
                        id: promptLabel
                        anchors.centerIn: parent
                        text: root.prompt
                        color: Theme.accent
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                // Result count, right-aligned in the well. Cheap feedback that
                // the ranker is actually narrowing as you type -- which is why
                // it stays hidden until something is typed: with an empty query
                // the number is just Theme.maxResults, and reporting the cap as
                // if it were a match count is worse than saying nothing.
                Text {
                    id: countLabel
                    anchors.right: field.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: field.verticalCenter
                    visible: root.query !== "" && root.results.length > 0
                    text: root.results.length
                    color: Theme.textFaint
                    font.pixelSize: 11
                }

                TextInput {
                    id: input
                    anchors.verticalCenter: field.verticalCenter
                    x: promptChip.x + promptChip.width + 10
                    width: field.x + field.width - x - (countLabel.visible ? countLabel.width + 20 : 12)
                    color: Theme.textPrimary
                    font.pixelSize: 15
                    selectionColor: Theme.accent
                    selectedTextColor: "#101014"
                    clip: true

                    // Focus is (re)taken in the window's onVisibleChanged;
                    // this only marks the input as the scope's focus target.
                    focus: true

                    onTextChanged: root.query = text

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.mode === "files" ? "type at least 2 characters…" : "type to search…"
                        color: Theme.textFaint
                        font.pixelSize: 14
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            root.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) {
                            if (root.results.length)
                                root.selected = (root.selected + 1) % root.results.length;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
                            if (root.results.length)
                                root.selected = (root.selected - 1 + root.results.length) % root.results.length;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.results[root.selected]);
                            event.accepted = true;
                        }
                    }
                }
            }

            // Inset like the notification card's row divider: it separates two
            // regions of one surface, so it must not run edge to edge the way
            // the panel's own outline does.
            Rectangle {
                anchors.top: searchRow.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.cardPadding
                anchors.rightMargin: Theme.cardPadding
                height: 1
                color: Theme.divider
                visible: list.count > 0
            }

            // --- Results ----------------------------------------------
            ListView {
                id: list
                anchors.top: searchRow.bottom
                anchors.topMargin: Theme.cardPadding / 2
                anchors.left: parent.left
                anchors.right: parent.right
                // ResultRow insets its own pill by 4, so trimming that off here
                // lines the selected row up with the edges of the search well.
                anchors.leftMargin: Theme.cardPadding - 4
                anchors.rightMargin: Theme.cardPadding - 4
                height: Math.min(contentHeight, Theme.maxListHeight)
                clip: true
                model: root.results
                currentIndex: root.selected
                highlightMoveDuration: Theme.animFast
                // Keep the selected row on screen when arrowing past the edge.
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: Theme.rowHeight
                preferredHighlightEnd: height - Theme.rowHeight

                delegate: ResultRow {
                    required property var modelData
                    required property int index

                    // Looked up rather than bound into the entry, so a preview
                    // landing repaints just this row.
                    readonly property var preview: root.mode === "clipboard"
                        ? (root.clipPreviews[modelData.payload] || null)
                        : null

                    width: list.width
                    label: modelData.label
                    sublabel: modelData.sublabel
                    iconName: modelData.icon
                    selected: index === root.selected

                    previewKind: preview ? preview.kind : ""
                    previewPath: preview ? preview.payload : ""

                    readonly property bool hasMedia: preview && preview.kind !== "icon"

                    rowH: hasMedia ? Theme.clipRowHeight : Theme.rowHeight
                    mediaW: hasMedia ? Theme.clipPreviewWidth : Theme.iconSize
                    mediaH: hasMedia ? Theme.clipPreviewHeight : Theme.iconSize

                    onHovered: root.selected = index
                    onActivated: root.activate(modelData)
                }
            }
        }
    }
}
