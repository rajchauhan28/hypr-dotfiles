pragma Singleton

import QtQuick
import QtQuick.LocalStorage
import Quickshell

// Notification history, persisted in SQLite through Qt's LocalStorage module
// (no extra process). The file lives under the engine's offline storage path,
// which follows the qs binary's app name -- with noctalia-qs that is
// ~/.local/share/noctalia-qs/QML/OfflineStorage/Databases/<md5>.sqlite, and the
// .ini beside it names it "quickshell-notifications".
Singleton {
    id: store

    // Newest first, as plain objects: {id, ts, app, icon, summary, body, urgency}.
    property var history: []
    property bool centerOpen: false

    property var _db: null

    function db() {
        if (!store._db) {
            store._db = LocalStorage.openDatabaseSync("quickshell-notifications", "", "Notification history", 5000000);
            store._db.transaction(function (tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS history ("
                              + "id INTEGER PRIMARY KEY AUTOINCREMENT, ts INTEGER NOT NULL, "
                              + "app TEXT, icon TEXT, summary TEXT, body TEXT, urgency INTEGER)");
                tx.executeSql("CREATE INDEX IF NOT EXISTS history_ts ON history(ts)");
            });
        }
        return store._db;
    }

    // An app's own image wins over its themed icon. image://icon/... (what
    // notify-send -i becomes) is a theme lookup and stays valid; any other
    // image:// URL is pixel data that dies with the notification and would
    // render blank from history.
    function iconFor(n) {
        var img = n.image || "";
        if (img.indexOf("file://") === 0 || img.indexOf("/") === 0 || img.indexOf("image://icon/") === 0)
            return img;
        return n.appIcon || "";
    }

    function record(n) {
        if (n.transient)
            return;
        var row = {
            ts: Date.now(),
            app: n.appName || "",
            icon: store.iconFor(n),
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency
        };
        store.db().transaction(function (tx) {
            var rs = tx.executeSql("INSERT INTO history (ts, app, icon, summary, body, urgency) VALUES (?, ?, ?, ?, ?, ?)",
                                   [row.ts, row.app, row.icon, row.summary, row.body, row.urgency]);
            row.id = parseInt(rs.insertId, 10);
            tx.executeSql("DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY ts DESC LIMIT ?)",
                          [Theme.historyMax]);
        });
        var next = store.history.slice();
        next.unshift(row);
        if (next.length > Theme.historyMax)
            next.length = Theme.historyMax;
        store.history = next;
    }

    function load() {
        var out = [];
        store.db().readTransaction(function (tx) {
            var rs = tx.executeSql("SELECT id, ts, app, icon, summary, body, urgency FROM history ORDER BY ts DESC LIMIT ?",
                                   [Theme.historyMax]);
            for (var i = 0; i < rs.rows.length; i++)
                out.push(rs.rows.item(i));
        });
        store.history = out;
    }

    function remove(id) {
        store.db().transaction(function (tx) {
            tx.executeSql("DELETE FROM history WHERE id = ?", [id]);
        });
        store.history = store.history.filter(function (r) { return r.id !== id; });
    }

    function clear() {
        store.db().transaction(function (tx) {
            tx.executeSql("DELETE FROM history");
        });
        store.history = [];
    }

    Component.onCompleted: store.load()
}
