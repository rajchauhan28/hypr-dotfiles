import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The local llama.cpp server: which model runs, whether it serves the browser
// UI, and whether opencode is offered the local providers. llm.py owns every
// model flag; this page only reads `llm.py status` and asks it to act.
ColumnLayout {
    id: page

    spacing: Theme.gap

    readonly property string backend: Quickshell.env("HOME") + "/.config/quickshell/settings/llm.py"

    property var st: null
    property bool busy: false
    property string actionTitle: ""
    property string actionLog: ""
    property string actionResult: ""

    // What Start will launch while nothing runs. Seeded from the running model,
    // else the last one started, until the user picks something.
    property string chosenModel: "e4b"
    property bool chosenWebui: true
    property bool chosenThinking: true
    property bool seeded: false

    readonly property var running: page.st ? page.st.running : null
    readonly property var models: page.st ? page.st.models : []

    function modelLabel(key) {
        for (var i = 0; i < page.models.length; i++)
            if (page.models[i].key === key)
                return page.models[i].label;
        return key;
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function act(args, title) {
        if (page.busy)
            return;
        page.busy = true;
        page.actionTitle = title;
        page.actionLog = "";
        page.actionResult = "";
        actionProc.command = ["python3", page.backend].concat(args);
        actionProc.running = true;
    }

    function startModel(key, webui, thinking) {
        page.chosenModel = key;
        page.chosenWebui = webui;
        page.chosenThinking = thinking;
        page.act(["start", key].concat(webui ? [] : ["--no-webui"], thinking ? ["--thinking"] : ["--no-thinking"]),
                 "Starting " + page.modelLabel(key));
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 4000
        repeat: true
        running: !page.busy
        onTriggered: page.refresh()
    }

    Process {
        id: statusProc
        command: ["python3", page.backend, "status"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    page.st = JSON.parse(data.trim());
                } catch (e) {
                    return;
                }
                if (page.running) {
                    page.chosenModel = page.running.model || page.chosenModel;
                    page.chosenWebui = page.running.webui;
                    page.chosenThinking = page.running.thinking;
                } else if (!page.seeded) {
                    page.chosenModel = page.st.last.model;
                    page.chosenWebui = page.st.last.webui;
                    page.chosenThinking = page.st.last.thinking;
                }
                page.seeded = true;
            }
        }
    }

    Process {
        id: actionProc

        stdout: SplitParser { onRead: data => page.actionLog += data + "\n" }
        stderr: SplitParser { onRead: data => page.actionLog += data + "\n" }
        onExited: code => {
            page.busy = false;
            page.actionResult = code === 0 ? "Done." : "Failed (exit " + code + "). See the log below.";
            page.refresh();
        }
    }

    component Toggle: Rectangle {
        id: toggle

        property bool checked: false
        property bool active: true
        signal toggled()

        implicitWidth: 40
        implicitHeight: 22
        radius: height / 2
        opacity: active ? 1 : 0.5
        color: checked ? Theme.accent : Theme.cardAlt
        border.color: checked ? Theme.accent : Theme.borderStrong
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: toggle.checked ? toggle.width - width - 3 : 3
            color: toggle.checked ? Theme.onAccent : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: 140 } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: toggle.active
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: toggle.toggled()
        }
    }

    component ActionButton: Rectangle {
        id: button

        property string text: ""
        property color edge: Theme.borderStrong
        property bool active: true
        signal clicked()

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 34
        radius: Theme.radiusSmall
        opacity: active ? 1 : 0.55
        color: mouse.containsMouse && active ? Theme.cardHover : Theme.cardAlt
        border.color: edge

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: Theme.textPrimary
            font.pixelSize: 11
            font.bold: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.active
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    Card {
        title: "SERVER"
        subtitle: page.running ? page.running.label + " on " + page.running.url : "Nothing running"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: !page.running ? Theme.textFaint : (page.running.healthy ? Theme.good : Theme.warn)
            }

            Text {
                Layout.fillWidth: true
                text: page.st === null ? "Checking..."
                    : !page.running ? "Stopped"
                    : (page.running.healthy ? "Running" : "Loading model...")
                      + (page.st.vramUsed !== null
                         ? "   ·   " + (page.st.vramUsed / 1024).toFixed(1) + " / "
                           + (page.st.vramTotal / 1024).toFixed(1) + " GB VRAM"
                         : "")
                color: Theme.textPrimary
                font.pixelSize: 11
            }

            ActionButton {
                visible: page.running !== null
                text: page.busy ? "Working..." : "Stop server"
                edge: Theme.danger
                active: !page.busy
                onClicked: page.act(["stop"], "Stopping the server")
            }

            ActionButton {
                visible: page.running === null
                text: page.busy ? "Working..." : "Start " + page.modelLabel(page.chosenModel)
                edge: Theme.accent
                active: !page.busy && page.st !== null
                onClicked: page.startModel(page.chosenModel, page.chosenWebui, page.chosenThinking)
            }
        }
    }

    Card {
        title: "MODEL"
        subtitle: page.running ? "Picking another one restarts the server with it" : "Used by Start"

        Repeater {
            model: page.models

            delegate: Rectangle {
                id: option

                required property var modelData

                readonly property bool selected: page.chosenModel === modelData.key
                readonly property bool usable: modelData.present && !page.busy

                Layout.fillWidth: true
                implicitHeight: optionText.implicitHeight + 20
                radius: Theme.radiusSmall
                color: selected ? Theme.cardHover : (optionMouse.containsMouse && usable ? Theme.cardAlt : "transparent")
                border.color: selected ? Theme.accent : "transparent"
                opacity: modelData.present ? 1 : 0.5

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        radius: 7
                        color: "transparent"
                        border.color: option.selected ? Theme.accent : Theme.borderStrong
                        border.width: 2

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.accent
                            visible: option.selected
                        }
                    }

                    ColumnLayout {
                        id: optionText
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: modelData.label + "   :" + modelData.port
                            font.pixelSize: 12
                            color: Theme.textPrimary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.present ? modelData.detail : "Model file missing"
                            font.pixelSize: 10
                            color: modelData.present ? Theme.textMuted : Theme.warn
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: option.usable && !option.selected
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (page.running)
                            page.startModel(modelData.key, page.chosenWebui, page.chosenThinking);
                        else
                            page.chosenModel = modelData.key;
                    }
                }
            }
        }
    }

    Card {
        title: "WEB UI"
        subtitle: page.running ? "Changing this restarts the server" : "Used by Start"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Serve the browser chat UI"
                color: Theme.textPrimary
                font.pixelSize: 11
            }

            ActionButton {
                visible: page.running !== null && page.running.webui && page.running.healthy
                text: "Open"
                onClicked: Quickshell.execDetached(["xdg-open", page.running.url])
            }

            Toggle {
                checked: page.chosenWebui
                active: !page.busy && page.st !== null
                onToggled: {
                    if (page.running && page.running.model)
                        page.startModel(page.running.model, !page.chosenWebui, page.chosenThinking);
                    else
                        page.chosenWebui = !page.chosenWebui;
                }
            }
        }
    }

    Card {
        title: "THINKING"
        subtitle: page.running ? "Changing this restarts the server" : "Used by Start"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Think before answering -- better at multi-step work, much slower per reply"
                color: Theme.textPrimary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Toggle {
                checked: page.chosenThinking
                active: !page.busy && page.st !== null
                onToggled: {
                    if (page.running && page.running.model)
                        page.startModel(page.running.model, page.chosenWebui, !page.chosenThinking);
                    else
                        page.chosenThinking = !page.chosenThinking;
                }
            }
        }
    }

    Card {
        title: "OPENCODE"
        // Only one local model is ever offered -- the running one, else the one
        // Start launches -- so opencode can never pick a port nothing serves.
        subtitle: page.st && page.st.opencodeModel
                  ? "Offers " + page.modelLabel(page.st.opencodeModel) + " only · new opencode sessions"
                  : "Applies to new opencode sessions"

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Offer the running model in opencode"
                color: Theme.textPrimary
                font.pixelSize: 11
            }

            Toggle {
                checked: page.st !== null && page.st.opencode
                active: !page.busy && page.st !== null
                onToggled: page.act(["opencode", checked ? "off" : "on"],
                                    checked ? "Hiding local models from opencode" : "Offering local models in opencode")
            }
        }
    }

    Card {
        visible: page.actionTitle !== ""
        title: page.actionTitle.toUpperCase()
        subtitle: page.busy ? "Loading a model can take up to a minute" : page.actionResult

        Text {
            Layout.fillWidth: true
            text: page.actionLog
            color: page.actionResult.indexOf("Failed") === 0 ? Theme.warn : Theme.textSecondary
            font.family: "monospace"
            font.pixelSize: 10
            lineHeight: 1.25
            wrapMode: Text.WrapAnywhere
        }
    }
}
