pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The settings store. Everything the app edits lives in exactly two files:
//
//   ~/.config/quickshell/settings.json   -- palette + panel geometry
//   ~/.config/quickshell/dock/pinned.json -- the dock's app list
//
// Both are file-watched by the panels themselves, so a write here reaches the
// running dock/topbar/sidepanel without restarting anything.
Singleton {
    id: cfg

    readonly property string settingsPath: "/home/reign/.config/quickshell/settings.json"
    readonly property string pinnedPath: "/home/reign/.config/quickshell/dock/pinned.json"

    // The single source of truth for what a knob means: its default, range and
    // label all come from here, so adding a knob is one entry plus one row in a
    // page. Panels carry the same defaults independently, so that a deleted
    // settings.json leaves them looking exactly like this.
    readonly property var defaults: ({
        "palette": {
            "accent": "#e4e4e7",
            "good": "#86d9a3",
            "warn": "#e0c26b",
            "danger": "#e06b6b",
            "panelBg": "#f2101014"
        },
        "dock": {
            "iconSlot": 52,
            "iconSize": 34,
            "dockPadding": 10,
            "hotspotHeight": 15,
            "hotspotWidthFraction": 0.25,
            "radiusPanel": 16,
            "cornerFillet": 20,
            "edgeLine": 5,
            "previewTileW": 176,
            "previewTileH": 110,
            "previewMaxTiles": 5
        },
        "topbar": {
            "panelWidth": 1280,
            "panelHeight": 720,
            "hotspotHeight": 15,
            "hotspotWidthFraction": 0.10,
            "radiusPanel": 20,
            "cornerFillet": 30,
            "edgeLine": 5,
            "gap": 16,
            "cardPadding": 18
        },
        "sidepanel": {
            "iconSlot": 48,
            "stripPadding": 8,
            "panelWidth": 50,
            "hotspotWidth": 15,
            "hotspotHeightFraction": 0.10,
            "radiusPanel": 16,
            "cornerFillet": 20,
            "edgeLine": 5,
            "osdWidth": 130
        },
        "leftbar": {
            "barWidth": 54,
            "iconSlot": 38,
            "barPadding": 10,
            "radiusPanel": 16,
            "radiusSmall": 10
        }
    })

    property var data: ({})
    property var pinned: []
    property var apps: []

    // Shown in the footer. Empty means "nothing pending".
    property string status: ""

    // ---- Reads ---------------------------------------------------------
    // Callers bind straight to these; reading cfg.data inside the function is
    // enough for QML to re-evaluate the binding when data changes.
    function get(section, key) {
        var s = cfg.data[section];
        if (s && s[key] !== undefined && s[key] !== null)
            return s[key];
        return cfg.defaults[section][key];
    }

    function isDefault(section, key) {
        return get(section, key) === cfg.defaults[section][key];
    }

    // ---- Writes --------------------------------------------------------
    // A fresh object every time, not a mutation: QML only re-evaluates
    // bindings on `data` when the property is *assigned*, so editing in place
    // would update the file and leave every slider showing the old value.
    function set(section, key, value) {
        var next = JSON.parse(JSON.stringify(cfg.data));
        if (!next[section])
            next[section] = {};
        next[section][key] = value;
        cfg.data = next;
        cfg.status = "Saving…";
        saveTimer.restart();
    }

    function resetSection(section) {
        var next = JSON.parse(JSON.stringify(cfg.data));
        next[section] = JSON.parse(JSON.stringify(cfg.defaults[section]));
        cfg.data = next;
        cfg.status = "Saving…";
        saveTimer.restart();
    }

    function setPinned(list) {
        cfg.pinned = list;
        cfg.status = "Saving…";
        pinnedSaveTimer.restart();
    }

    // The dock's list lives here rather than in the page so the mutations can
    // be exercised without a pointer, and so any future caller gets the same
    // duplicate guard.
    function reorderPinned(index, delta) {
        var list = cfg.pinned.slice();
        var target = index + delta;
        if (index < 0 || index >= list.length || target < 0 || target >= list.length)
            return;
        var moved = list.splice(index, 1)[0];
        list.splice(target, 0, moved);
        setPinned(list);
    }

    function removePinned(index) {
        if (index < 0 || index >= cfg.pinned.length)
            return;
        var list = cfg.pinned.slice();
        list.splice(index, 1);
        setPinned(list);
    }

    function addPinned(app) {
        var list = cfg.pinned.slice();
        for (var i = 0; i < list.length; i++)
            if (list[i]["class"] === app["class"])
                return;   // already pinned; a second entry would give it two slots
        list.push({
            "name": app.name,
            "exec": app.exec,
            "class": app["class"],
            "icon": app.icon
        });
        setPinned(list);
    }

    // Dragging a slider emits a change per pixel; one write per gesture is
    // plenty, and it keeps the panels from re-laying out mid-drag.
    Timer {
        id: saveTimer
        interval: 350
        repeat: false
        onTriggered: cfg.write(settingsWriter, cfg.settingsPath, cfg.data)
    }

    Timer {
        id: pinnedSaveTimer
        interval: 250
        repeat: false
        onTriggered: cfg.write(pinnedWriter, cfg.pinnedPath, { "pinned": cfg.pinned })
    }

    function write(proc, path, obj) {
        // Setting running=true on an already-running Process silently drops the
        // command, so one slow write would swallow the next one entirely.
        proc.running = false;
        proc.command = ["python3", "/home/reign/.config/quickshell/settings/store.py",
                        path, JSON.stringify(obj)];
        proc.running = true;
    }

    Process {
        id: settingsWriter
        onExited: code => cfg.status = code === 0 ? "Saved" : "Write failed"
    }

    Process {
        id: pinnedWriter
        onExited: code => cfg.status = code === 0 ? "Saved" : "Write failed"
    }

    // Clear the footer note a moment after it lands, so it reads as a flash of
    // confirmation rather than permanent chrome.
    onStatusChanged: if (cfg.status === "Saved") statusClear.restart()

    Timer {
        id: statusClear
        interval: 1600
        repeat: false
        onTriggered: if (cfg.status === "Saved") cfg.status = ""
    }

    // ---- Loads ---------------------------------------------------------
    // watchChanges both ways: editing the JSON by hand updates the app, and a
    // panel is never the only thing that noticed.
    FileView {
        path: cfg.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                cfg.data = JSON.parse(text()) || ({});
            } catch (e) {
                // Leave the last good copy in place; the defaults still apply
                // to anything the broken file was supposed to override.
            }
        }
    }

    FileView {
        path: cfg.pinnedPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text());
                cfg.pinned = d.pinned || [];
            } catch (e) {}
        }
    }

    Process {
        id: appsProc
        running: true
        command: ["python3", "/home/reign/.config/quickshell/settings/apps.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    cfg.apps = JSON.parse(data.trim()).apps || [];
                } catch (e) {}
            }
        }
    }

    function refreshApps() {
        appsProc.running = false;
        appsProc.running = true;
    }
}
