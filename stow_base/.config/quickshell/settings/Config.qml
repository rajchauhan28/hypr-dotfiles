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
    readonly property string sidebarPinnedPath: "/home/reign/.config/quickshell/sidebar_pinned.json"

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
        },
        "lockscreen": {
            "icon": ""
        }
    })

    property var data: ({})
    property var pinned: []
    property var sidebarPinned: []
    property var apps: []
    property string osName: "Linux"
    property string osIcon: ""

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

    function setSidebarPinned(list) {
        cfg.sidebarPinned = list;
        cfg.status = "Saving…";
        sidebarPinnedSaveTimer.restart();
    }

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
                return;
        list.push({
            "name": app.name,
            "exec": app.exec,
            "class": app["class"],
            "icon": app.icon
        });
        setPinned(list);
    }

    function changePinnedIcon(index, newIconName) {
        if (index < 0 || index >= cfg.pinned.length)
            return;
        var list = JSON.parse(JSON.stringify(cfg.pinned));
        list[index].icon = newIconName;
        setPinned(list);
    }

    function reorderSidebarPinned(index, delta) {
        var list = cfg.sidebarPinned.slice();
        var target = index + delta;
        if (index < 0 || index >= list.length || target < 0 || target >= list.length)
            return;
        var moved = list.splice(index, 1)[0];
        list.splice(target, 0, moved);
        setSidebarPinned(list);
    }

    function removeSidebarPinned(index) {
        if (index < 0 || index >= cfg.sidebarPinned.length)
            return;
        var list = cfg.sidebarPinned.slice();
        list.splice(index, 1);
        setSidebarPinned(list);
    }

    function addSidebarPinned(app) {
        var list = cfg.sidebarPinned.slice();
        for (var i = 0; i < list.length; i++)
            if (list[i]["class"] === app["class"])
                return;
        list.push({
            "name": app.name,
            "exec": app.exec,
            "class": app["class"],
            "icon": app.icon
        });
        setSidebarPinned(list);
    }

    function changeSidebarPinnedIcon(index, newIconName) {
        if (index < 0 || index >= cfg.sidebarPinned.length)
            return;
        var list = JSON.parse(JSON.stringify(cfg.sidebarPinned));
        list[index].icon = newIconName;
        setSidebarPinned(list);
    }

    function getAvailableIcon(iconName, appName, appClass) {
        if (iconName && Quickshell.iconPath(iconName, true) !== "")
            return iconName;

        var searchName = (appName || "").toLowerCase();
        var searchClass = (appClass || "").toLowerCase();
        for (var i = 0; i < cfg.apps.length; i++) {
            var a = cfg.apps[i];
            if (!a.icon) continue;
            var aName = (a.name || "").toLowerCase();
            var aClass = (a["class"] || "").toLowerCase();
            if ((searchName !== "" && aName.indexOf(searchName) !== -1) ||
                (searchClass !== "" && aClass.indexOf(searchClass) !== -1)) {
                if (Quickshell.iconPath(a.icon, true) !== "")
                    return a.icon;
            }
        }

        for (var j = 0; j < cfg.apps.length; j++) {
            if (cfg.apps[j].icon && Quickshell.iconPath(cfg.apps[j].icon, true) !== "")
                return cfg.apps[j].icon;
        }

        return iconName || appClass || "";
    }

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

    Timer {
        id: sidebarPinnedSaveTimer
        interval: 250
        repeat: false
        onTriggered: cfg.write(sidebarPinnedWriter, cfg.sidebarPinnedPath, { "pinned": cfg.sidebarPinned })
    }

    function write(proc, path, obj) {
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

    Process {
        id: sidebarPinnedWriter
        onExited: code => cfg.status = code === 0 ? "Saved" : "Write failed"
    }

    onStatusChanged: if (cfg.status === "Saved") statusClear.restart()

    Timer {
        id: statusClear
        interval: 1600
        repeat: false
        onTriggered: if (cfg.status === "Saved") cfg.status = ""
    }

    FileView {
        path: cfg.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                cfg.data = JSON.parse(text()) || ({});
            } catch (e) {}
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

    FileView {
        path: cfg.sidebarPinnedPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(text());
                cfg.sidebarPinned = d.pinned || [];
            } catch (e) {
                cfg.sidebarPinned = [
                    { name: "Terminal", exec: "kitty", "class": "kitty", icon: "kitty" },
                    { name: "Browser", exec: "firefox", "class": "firefox", icon: "firefox" },
                    { name: "Files", exec: "thunar", "class": "org.xfce.thunar", icon: "org.xfce.thunar" },
                    { name: "Code", exec: "code", "class": "Code", icon: "vscode" }
                ];
            }
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

    Process {
        id: systemInfoProc
        running: true
        command: ["python3", "/home/reign/.config/quickshell/settings/system_info.py"]
        stdout: SplitParser {
            onRead: output => {
                try {
                    var info = JSON.parse(output.trim());
                    cfg.osName = info.name || "Linux";
                    cfg.osIcon = info.icon || Quickshell.iconPath(info.logoName || info.id, true);
                } catch (e) {}
            }
        }
    }

    function refreshApps() {
        appsProc.running = false;
        appsProc.running = true;
    }
}
