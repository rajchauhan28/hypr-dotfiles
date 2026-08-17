import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings for the shell: the dock's app list, the three panels' geometry, and
// the shared palette. A plain floating window rather than a layer-shell panel,
// so the compositor treats it like any other app (tile it, float it, Super+Q).
ShellRoot {
    id: root

    property int pageIndex: 0

    // This Quickshell build exposes no quit()/exit() on the Quickshell
    // singleton -- only processId. Signalling ourselves is the working exit,
    // and without it closing the window would leave an invisible process
    // holding the config name, so the next launch would silently do nothing.
    function quitSelf() {
        Quickshell.execDetached(["kill", String(Quickshell.processId)]);
    }

    // The source lives with the entry: a parallel if/else chain in the Loader
    // silently fell through to the last page whenever this list grew.
    readonly property var pages: [
        { key: "dock", glyph: "󰇘", label: "Dock", hint: "Pinned apps and dock size", source: "DockPage.qml" },
        { key: "sidebar", glyph: "󰕮", label: "Sidebar", hint: "Left sidebar apps & size", source: "SidebarPage.qml" },
        { key: "panels", glyph: "󰕰", label: "Panels", hint: "Top and right panel geometry", source: "PanelsPage.qml" },
        { key: "notifications", glyph: "󰂚", label: "Notifications", hint: "Popup shape and timeouts", source: "NotificationsPage.qml" },
        { key: "appearance", glyph: "󰸌", label: "Appearance", hint: "Shared palette", source: "AppearancePage.qml" },
        { key: "lockscreen", glyph: "󰌾", label: "Lockscreen", hint: "User icon and assets", source: "LockscreenPage.qml" }
    ]

    FloatingWindow {
        id: win

        title: "Shell Settings"
        implicitWidth: 900
        implicitHeight: 640
        minimumSize: Qt.size(720, 480)
        color: Theme.windowBg
        visible: true

        // Nothing here runs in the background, so closing the window ends the
        // process rather than leaving an invisible instance behind.
        onClosed: root.quitSelf()

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---- Navigation -------------------------------------------
            Rectangle {
                Layout.preferredWidth: 196
                Layout.fillHeight: true
                color: Theme.panelBg

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Theme.border
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10
                        spacing: 1

                        Text {
                            text: "SHELL"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.6
                            color: Theme.textMuted
                        }
                        Text {
                            text: "Settings"
                            font.pixelSize: 19
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }

                    Repeater {
                        model: root.pages

                        delegate: Rectangle {
                            id: navItem

                            required property var modelData
                            required property int index

                            readonly property bool current: root.pageIndex === index

                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Theme.radiusSmall
                            color: current ? Theme.cardHover
                                           : (navMouse.containsMouse ? Theme.card : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }

                            // Accent bar on the selected item, sized from the
                            // parent's height so it tracks the row.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: navItem.current ? navItem.height - 16 : 0
                                radius: 1.5
                                color: Theme.accent
                                Behavior on height { NumberAnimation { duration: 150 } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: modelData.glyph
                                    font.pixelSize: 15
                                    color: navItem.current ? Theme.accent : Theme.textSecondary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        text: modelData.label
                                        font.pixelSize: 12
                                        color: Theme.textPrimary
                                    }
                                    Text {
                                        text: modelData.hint
                                        font.pixelSize: 9
                                        color: Theme.textFaint
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pageIndex = index
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Saving is automatic, so the only feedback worth showing is
                    // that a write happened -- and that it succeeded.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Config.status === "Write failed" ? Theme.danger : Theme.good
                            opacity: Config.status === "" ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Config.status === "" ? "Saves as you edit" : Config.status
                            font.pixelSize: 9
                            color: Config.status === "Write failed" ? Theme.danger : Theme.textFaint
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Panels update live — nothing needs restarting."
                        font.pixelSize: 9
                        lineHeight: 1.4
                        color: Theme.textFaint
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ---- Page -------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 18
                    anchors.rightMargin: 12
                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.height
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: pageLoader
                        width: flick.width
                        // The page is a ColumnLayout, which reports its natural
                        // height through implicitHeight; the Loader has to be
                        // told to take it, or the Flickable never scrolls.
                        height: item ? item.implicitHeight : 0
                        source: root.pages[root.pageIndex].source
                        // Switching to a shorter page while scrolled down left
                        // the view parked past the end, showing empty space
                        // until you flicked it back.
                        onSourceChanged: flick.contentY = 0
                    }
                }

                // Slim scrollbar; only visible when there is somewhere to go.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    width: 4
                    radius: 2
                    color: Theme.borderStrong
                    visible: flick.contentHeight > flick.height
                    y: 18 + (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                       * (flick.height - height)
                    height: Math.max(30, flick.height * (flick.height / Math.max(1, flick.contentHeight)))
                }
            }
        }
    }

    // Scripting hook, so a keybind can raise an already-open window instead of
    // failing with "already running".
    IpcHandler {
        target: "settings"

        // NOT `show`: that is a real `qs ipc` subcommand and the CLI swallows
        // the name before it reaches the handler.
        function open(): void { win.visible = true; }
        function quit(): void { root.quitSelf(); }
        function page(name: string): void {
            for (var i = 0; i < root.pages.length; i++)
                if (root.pages[i].key === name)
                    root.pageIndex = i;
            win.visible = true;
        }
    }
}
