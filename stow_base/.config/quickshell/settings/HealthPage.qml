import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Health: is everything this setup depends on actually working? The checks
// live in health.py (read-only, time-boxed); this page lists them by group and
// offers the fix a check suggests. Fixes only start, restart or rebuild.
ColumnLayout {
    id: page

    spacing: Theme.gap

    property var checks: []
    property bool loading: false

    readonly property var groups: {
        var order = [], by = {};
        for (var i = 0; i < page.checks.length; i++) {
            var c = page.checks[i];
            if (!(c.group in by)) {
                by[c.group] = [];
                order.push(c.group);
            }
            by[c.group].push(c);
        }
        var out = [];
        for (var j = 0; j < order.length; j++)
            out.push({ name: order[j], items: by[order[j]] });
        return out;
    }

    function count(status) {
        var n = 0;
        for (var i = 0; i < page.checks.length; i++)
            if (page.checks[i].status === status)
                n++;
        return n;
    }

    function colorFor(status) {
        if (status === "ok") return Theme.good;
        if (status === "warn") return Theme.warn;
        if (status === "fail") return Theme.danger;
        return Theme.textMuted;
    }

    function refresh() {
        if (healthProc.running)
            return;
        page.loading = true;
        healthProc.running = true;
    }

    function runFix(fix) {
        Quickshell.execDetached(fix.cmd);
        // Most fixes (restart a unit, start the lock daemon) settle within a
        // second or two; long ones (a rebuild) run in their own terminal and
        // the user can press Refresh after.
        refreshDelay.restart();
    }

    Component.onCompleted: refresh()

    Process {
        id: healthProc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/quickshell/settings/health.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.checks = JSON.parse(text).checks || [];
                } catch (e) {
                    page.checks = [{ group: "Health", title: "health.py", status: "fail",
                                     detail: "Could not read its output." }];
                }
                page.loading = false;
            }
        }
        onExited: page.loading = false
    }

    Timer {
        id: refreshDelay
        interval: 2500
        repeat: false
        onTriggered: page.refresh()
    }

    Card {
        Layout.fillWidth: true
        title: "HEALTH"
        subtitle: page.loading && page.checks.length === 0 ? "Checking…"
                : page.count("fail") + page.count("warn") === 0
                  ? "Everything checked is working."
                  : (page.count("fail") > 0 ? page.count("fail") + " failing, " : "")
                    + page.count("warn") + " need attention, " + page.count("ok") + " fine"

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Repeater {
                model: [["ok", "fine"], ["warn", "attention"], ["fail", "failing"], ["info", "info"]]

                RowLayout {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: page.colorFor(modelData[0])
                    }
                    Text {
                        text: page.count(modelData[0]) + " " + modelData[1]
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: refreshLabel.implicitWidth + 24
                implicitHeight: 32
                radius: Theme.radiusSmall
                color: refreshMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                border.color: Theme.border

                Text {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: page.loading ? "Checking…" : "Refresh"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !page.loading
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.refresh()
                }
            }
        }
    }

    Repeater {
        model: page.groups

        Card {
            id: groupCard
            required property var modelData
            Layout.fillWidth: true
            title: modelData.name.toUpperCase()

            Repeater {
                model: groupCard.modelData.items

                RowLayout {
                    id: checkRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 5
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: page.colorFor(checkRow.modelData.status)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: checkRow.modelData.title
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: checkRow.modelData.detail
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        visible: !!checkRow.modelData.fix
                        implicitWidth: fixLabel.implicitWidth + 24
                        implicitHeight: 30
                        radius: Theme.radiusSmall
                        color: fixMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                        border.color: checkRow.modelData.status === "info" ? Theme.borderStrong : Theme.accent

                        Text {
                            id: fixLabel
                            anchors.centerIn: parent
                            text: checkRow.modelData.fix ? checkRow.modelData.fix.label : ""
                            color: Theme.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: fixMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.runFix(checkRow.modelData.fix)
                        }
                    }
                }
            }
        }
    }
}
