import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page

    spacing: Theme.gap

    readonly property string manager: Quickshell.env("HOME") + "/.local/bin/damx-driver-manager"
    property bool busy: false
    property string statusText: "Checking DAMX status..."
    property string actionTitle: ""
    property string actionLog: ""
    property string actionResult: ""

    function cleanOutput(output) {
        return output.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "").replace(/\r/g, "");
    }

    function appendAction(output) {
        var cleaned = cleanOutput(output);
        if (cleaned === "")
            return;
        actionLog += cleaned + "\n";
        if (actionLog.length > 16000)
            actionLog = actionLog.slice(actionLog.length - 16000);
    }

    function refreshStatus() {
        if (statusProc.running)
            return;
        statusText = "Checking DAMX status...";
        statusProc.running = true;
    }

    function runAction(mode, title) {
        if (busy)
            return;
        busy = true;
        actionTitle = title;
        actionLog = "Waiting for administrator approval...\n";
        actionResult = "";
        actionProc.command = ["pkexec", manager, mode, "reign"];
        actionProc.running = true;
    }

    Component.onCompleted: refreshStatus()

    Process {
        id: statusProc
        command: [page.manager, "status"]

        stdout: SplitParser {
            onRead: output => {
                var line = page.cleanOutput(output).trim();
                if (line === "")
                    return;
                if (page.statusText === "Checking DAMX status...")
                    page.statusText = line;
                else
                    page.statusText += "\n" + line;
            }
        }
        stderr: SplitParser {
            onRead: output => page.statusText = page.cleanOutput(output).trim()
        }
        onExited: code => {
            if (code !== 0 && page.statusText === "Checking DAMX status...")
                page.statusText = "Could not read DAMX status (exit " + code + ").";
        }
    }

    Process {
        id: actionProc

        stdout: SplitParser { onRead: output => page.appendAction(output) }
        stderr: SplitParser { onRead: output => page.appendAction(output) }
        onExited: code => {
            page.busy = false;
            page.actionResult = code === 0
                ? "Finished successfully."
                : (code === 126
                   ? "Administrator approval was cancelled."
                   : "The action failed with exit code " + code + ". See the log below.");
            refreshDelay.restart();
        }
    }

    Timer {
        id: refreshDelay
        interval: 350
        repeat: false
        onTriggered: page.refreshStatus()
    }

    Card {
        Layout.fillWidth: true
        title: "DAMX STATUS"
        subtitle: "Linuwu-Sense on the running kernel"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: page.statusText.indexOf("missing") >= 0
                       || page.statusText.indexOf("not loaded") >= 0
                       || page.statusText.indexOf("not installed") >= 0
                       ? Theme.warn : Theme.good
            }

            Text {
                Layout.fillWidth: true
                text: page.statusText
                color: Theme.textPrimary
                font.family: "monospace"
                font.pixelSize: 11
                lineHeight: 1.35
                wrapMode: Text.WrapAnywhere
            }

            Rectangle {
                implicitWidth: refreshLabel.implicitWidth + 24
                implicitHeight: 32
                radius: Theme.radiusSmall
                color: refreshMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                border.color: Theme.border

                Text {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: "Refresh"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !statusProc.running
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.refreshStatus()
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "KERNEL DRIVER"
        subtitle: "Fast repair for the current CachyOS kernel"

        Text {
            Layout.fillWidth: true
            text: "Builds the patched Linuwu-Sense module, loads it, and installs a pacman hook. After that, every linux-cachyos kernel or headers upgrade rebuilds the driver automatically before you reboot."
            color: Theme.textSecondary
            font.pixelSize: 11
            lineHeight: 1.35
            wrapMode: Text.WordWrap
        }

        Rectangle {
            implicitWidth: rebuildLabel.implicitWidth + 28
            implicitHeight: 36
            radius: Theme.radiusSmall
            opacity: page.busy ? 0.55 : 1
            color: rebuildMouse.containsMouse && !page.busy ? Theme.cardHover : Theme.cardAlt
            border.color: Theme.accent

            Text {
                id: rebuildLabel
                anchors.centerIn: parent
                text: page.busy ? "Working..." : "Rebuild driver + enable hook"
                color: Theme.textPrimary
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                id: rebuildMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !page.busy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: page.runAction("install", "Driver rebuild")
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "FULL DAMX SUITE"
        subtitle: "Restore the daemon and GUI after the failed upstream install"

        Text {
            Layout.fillWidth: true
            text: "Downloads the latest checksum-verified DAMX release, applies the Linux 7.2 compatibility patch when needed, and installs its driver, daemon, and GUI. This is the longer operation."
            color: Theme.textSecondary
            font.pixelSize: 11
            lineHeight: 1.35
            wrapMode: Text.WordWrap
        }

        Rectangle {
            implicitWidth: suiteLabel.implicitWidth + 28
            implicitHeight: 36
            radius: Theme.radiusSmall
            opacity: page.busy ? 0.55 : 1
            color: suiteMouse.containsMouse && !page.busy ? Theme.cardHover : Theme.cardAlt
            border.color: Theme.borderStrong

            Text {
                id: suiteLabel
                anchors.centerIn: parent
                text: page.busy ? "Working..." : "Install complete DAMX Suite"
                color: Theme.textPrimary
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                id: suiteMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !page.busy
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: page.runAction("suite", "Full DAMX Suite installation")
            }
        }
    }

    Card {
        Layout.fillWidth: true
        visible: page.actionTitle !== ""
        title: page.actionTitle.toUpperCase()
        subtitle: page.busy ? "Keep this settings window open" : page.actionResult

        Text {
            Layout.fillWidth: true
            text: page.actionLog
            color: page.actionResult.indexOf("failed") >= 0 ? Theme.warn : Theme.textSecondary
            font.family: "monospace"
            font.pixelSize: 10
            lineHeight: 1.25
            wrapMode: Text.WrapAnywhere
        }
    }
}

