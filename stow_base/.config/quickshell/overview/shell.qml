import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property var allClients: []
    property var activeWsId: 1
    property string searchQuery: ""

    // Number of window cards currently being dragged. While > 0 we must NOT
    // refresh the client list: reassigning allClients resets every Repeater
    // model, which destroys the delegate under the cursor and kills the drag.
    property int dragCount: 0
    property string lastClientsJson: ""

    // Fetch clients and active workspace
    Timer {
        id: pollTimer
        interval: 1000
        running: root.dragCount === 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            clientsProc.running = true;
            activeWsProc.running = true;
        }
    }

    // Hyprland needs a moment to apply the move before the list is re-queried.
    Timer {
        id: postDropRefresh
        interval: 200
        repeat: false
        onTriggered: root.refreshNow()
    }

    function refreshNow() {
        clientsProc.running = true;
        activeWsProc.running = true;
    }

    Process {
        id: clientsProc
        command: ["bash", "-c", "hyprctl -j clients | tr -d '\\n'"]
        stdout: SplitParser {
            onRead: data => {
                var txt = data.trim();
                // Only rebuild the models when something actually changed,
                // otherwise the Repeaters churn once a second for nothing.
                if (txt === root.lastClientsJson)
                    return;
                try {
                    var parsed = JSON.parse(txt);
                    root.lastClientsJson = txt;
                    root.allClients = parsed;
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
                    var parsed = JSON.parse(data.trim());
                    root.activeWsId = parsed.id || 1;
                } catch (e) {}
            }
        }
    }

    function runCmd(args) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = args;
        p.running = true;
    }

    function dispatchHypr(cmdStr) {
        console.log("dispatchHypr called with:", cmdStr);
        var firstSpace = cmdStr.indexOf(" ");
        var cmd = [ Quickshell.env("HOME") + "/.config/quickshell/overview/hyprctl-compat.sh" ];
        if (firstSpace !== -1) {
            cmd.push(cmdStr.substring(0, firstSpace));
            cmd.push(cmdStr.substring(firstSpace + 1));
        } else {
            cmd.push(cmdStr);
        }
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = cmd;
        p.running = true;
    }

    function getWindowsForWorkspace(wsId) {
        var res = [];
        var query = root.searchQuery.trim().toLowerCase();
        for (var i = 0; i < root.allClients.length; i++) {
            var c = root.allClients[i];
            var matchWs = false;
            if (typeof wsId === "string" && wsId.startsWith("special:")) {
                matchWs = (c.workspace && c.workspace.name === wsId);
            } else {
                matchWs = (c.workspace && c.workspace.id === wsId);
            }

            if (matchWs) {
                if (query === "" ||
                    (c.title && c.title.toLowerCase().indexOf(query) !== -1) ||
                    (c.class && c.class.toLowerCase().indexOf(query) !== -1)) {
                    res.push(c);
                }
            }
        }
        return res;
    }

    function closeOverview() {
        closeAnim.start();
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: modalCard; property: "scale"; to: 0.94; duration: 160; easing.type: Easing.InQuint }
            NumberAnimation { target: modalCard; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.InQuint }
            NumberAnimation { target: modalBg; property: "opacity"; to: 0.0; duration: 180; easing.type: Easing.OutQuint }
        }
        ScriptAction { script: Qt.quit() }
    }

    PanelWindow {
        id: win
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-overview"

        Item {
            anchors.fill: parent

            Rectangle {
                id: modalBg
                anchors.fill: parent
                color: "#60000000"
                opacity: 0.0
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeOverview()
            }

            Rectangle {
                id: modalCard
                width: 1070
                height: 720
                anchors.centerIn: parent
                color: "#0a0a0f"
                border.color: "#18ffffff"
                border.width: 1
                radius: 20
                scale: 1.0
                opacity: 0.0

                ParallelAnimation {
                    running: true
                    NumberAnimation { target: modalCard; property: "scale"; from: 0.94; to: 1.0; duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.05 }
                    NumberAnimation { target: modalCard; property: "opacity"; from: 0.0; to: 1.0; duration: Theme.animNormal; easing.type: Theme.easeOutQuint }
                    NumberAnimation { target: modalBg; property: "opacity"; from: 0.0; to: 1.0; duration: Theme.animNormal; easing.type: Theme.easeOutQuint }
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    // Header / Search
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Text {
                            text: "✦ OVERVIEW"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 8
                            color: "#0cffffff"
                            border.color: "#15ffffff"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text { text: "🔍"; font.pixelSize: 14; color: "#71717a" }

                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                    clip: true
                                    focus: true
                                    Text {
                                        text: "Search open windows or apps..."
                                        color: "#52525b"
                                        visible: searchInput.text === ""
                                        font.pixelSize: 14
                                    }
                                    onTextChanged: {
                                        root.searchQuery = text;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 6
                            color: closeMouse.containsMouse ? "#20ffffff" : "#0cffffff"
                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 18
                                color: "#a1a1aa"
                            }
                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeOverview()
                            }
                        }
                    }

                    // Workspaces Grid
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        
                        ColumnLayout {
                            width: parent.width
                            spacing: 16

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 5
                                rows: 2
                                rowSpacing: 12
                                columnSpacing: 12

                                Repeater {
                                    model: 10
                                    delegate: WorkspaceCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        workspaceId: modelData + 1
                                        workspaceName: (modelData + 1).toString()
                                        isActive: (modelData + 1) === root.activeWsId
                                        windows: root.getWindowsForWorkspace(modelData + 1)
                                        dragOverlay: windowDragOverlay

                                        onDragStarted: root.dragCount++
                                        onDragEnded: root.dragCount = Math.max(0, root.dragCount - 1)

                                        onWorkspaceSelected: wsId => {
                                            root.dispatchHypr("workspace " + wsId);
                                            root.closeOverview();
                                        }
                                        onWindowFocusRequested: addr => {
                                            root.dispatchHypr("focuswindow address:" + addr);
                                            root.closeOverview();
                                        }
                                        onWindowCloseRequested: addr => {
                                            root.dispatchHypr("closewindow address:" + addr);
                                        }
                                        onWindowDrop: addr => {
                                            root.dispatchHypr("movetoworkspacesilent " + workspaceId + ",address:" + addr);
                                            postDropRefresh.restart();
                                        }
                                    }
                                }
                            }

                            // Separator
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: "#15ffffff"
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                            }

                            // Special Workspaces (50/50 Split)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                WorkspaceCard {
                                    Layout.fillWidth: true
                                    implicitHeight: 180
                                    workspaceId: "special:magic"
                                    workspaceName: "Special"
                                    isActive: root.activeWsId < 0
                                    windows: root.getWindowsForWorkspace("special:magic")
                                    dragOverlay: windowDragOverlay

                                    onDragStarted: root.dragCount++
                                    onDragEnded: root.dragCount = Math.max(0, root.dragCount - 1)

                                    onWorkspaceSelected: wsId => {
                                        root.dispatchHypr("togglespecialworkspace magic");
                                        root.closeOverview();
                                    }
                                    onWindowFocusRequested: addr => {
                                        root.dispatchHypr("focuswindow address:" + addr);
                                        root.closeOverview();
                                    }
                                    onWindowCloseRequested: addr => {
                                        root.dispatchHypr("closewindow address:" + addr);
                                    }
                                    onWindowDrop: addr => {
                                        root.dispatchHypr("movetoworkspacesilent " + workspaceId + ",address:" + addr);
                                        postDropRefresh.restart();
                                    }
                                }

                                // Vertical Separator
                                Rectangle {
                                    Layout.fillHeight: true
                                    implicitWidth: 1
                                    color: "#15ffffff"
                                }

                                WorkspaceCard {
                                    Layout.fillWidth: true
                                    implicitHeight: 180
                                    workspaceId: "special:S-term"
                                    workspaceName: "Scratchpad"
                                    isActive: root.activeWsId < 0
                                    windows: root.getWindowsForWorkspace("special:S-term")
                                    dragOverlay: windowDragOverlay

                                    onDragStarted: root.dragCount++
                                    onDragEnded: root.dragCount = Math.max(0, root.dragCount - 1)

                                    onWorkspaceSelected: wsId => {
                                        root.dispatchHypr("togglespecialworkspace S-term");
                                        root.closeOverview();
                                    }
                                    onWindowFocusRequested: addr => {
                                        root.dispatchHypr("focuswindow address:" + addr);
                                        root.closeOverview();
                                    }
                                    onWindowCloseRequested: addr => {
                                        root.dispatchHypr("closewindow address:" + addr);
                                    }
                                    onWindowDrop: addr => {
                                        root.dispatchHypr("movetoworkspacesilent " + workspaceId + ",address:" + addr);
                                        postDropRefresh.restart();
                                    }
                                }
                            }
                        }
                    }

                    // Footer / Quick Info
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Press Esc or click outside to dismiss  •  Middle-click window to close"
                            font.pixelSize: 11
                            color: "#71717a"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.allClients.length + " Total Windows Active"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#a1a1aa"
                        }
                    }
                }

                // Dragged window cards are reparented here for the duration of
                // the drag so they render above every workspace tile and are
                // not clipped by the ScrollView. Accepts no input itself.
                Item {
                    id: windowDragOverlay
                    anchors.fill: parent
                    z: 999
                }
            }
        }
    }
}
