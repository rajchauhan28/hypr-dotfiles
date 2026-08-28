import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property string timeStr: ""
    property string dateStr: ""

    // Navigation & Selected Date state
    property int displayMonth: new Date().getMonth()
    property int displayYear: new Date().getFullYear()

    property int selDay: new Date().getDate()
    property int selMonth: new Date().getMonth()
    property int selYear: new Date().getFullYear()

    property var eventsData: ({})
    property var selectedEvents: []
    property bool hasEntered: false

    function getFormattedKey(y, m, d) {
        var mm = (m + 1) < 10 ? ("0" + (m + 1)) : (m + 1);
        var dd = d < 10 ? ("0" + d) : d;
        return y + "-" + mm + "-" + dd;
    }

    function updateSelectedEvents() {
        var k = getFormattedKey(root.selYear, root.selMonth, root.selDay);
        root.selectedEvents = (root.eventsData && root.eventsData[k]) ? root.eventsData[k] : [];
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            root.timeStr = Qt.formatDateTime(d, "hh:mm:ss AP");
            root.dateStr = Qt.formatDateTime(d, "dddd, MMMM d, yyyy");
        }
    }

    Process {
        id: eventsProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/widgets/clock/events.py", "list"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.eventsData = JSON.parse(data) || {};
                    root.updateSelectedEvents();
                } catch(e) {}
            }
        }
        Component.onCompleted: eventsProc.running = true
    }

    function runEventsCmd(args) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root);
        p.command = args;
        p.stdout = Qt.createQmlObject('import Quickshell.Io; SplitParser {}', root);
        p.stdout.onRead.connect(function(data) {
            try {
                root.eventsData = JSON.parse(data) || {};
                root.updateSelectedEvents();
            } catch(e) {}
        });
        p.running = true;
    }

    function prevMonth() {
        if (root.displayMonth === 0) {
            root.displayMonth = 11;
            root.displayYear--;
        } else {
            root.displayMonth--;
        }
    }

    function nextMonth() {
        if (root.displayMonth === 11) {
            root.displayMonth = 0;
            root.displayYear++;
        } else {
            root.displayMonth++;
        }
    }

    function resetToday() {
        var d = new Date();
        root.displayMonth = d.getMonth();
        root.displayYear = d.getFullYear();
        root.selDay = d.getDate();
        root.selMonth = d.getMonth();
        root.selYear = d.getFullYear();
        root.updateSelectedEvents();
    }

    function closeWidget() {
        closeAnim.start();
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: glassPane; property: "height"; to: 0; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: glassPane; property: "opacity"; to: 0; duration: 150 }
        }
        ScriptAction { script: Qt.quit() }
    }

    PanelWindow {
        id: win
        anchors {
            top: true
            right: true
        }
        margins {
            top: 15
            right: 130
        }

        implicitWidth: 360
        implicitHeight: 520
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hasEntered = true
            onExited: {
                if (root.hasEntered) root.closeWidget();
            }

            Rectangle {
                id: glassPane
                anchors.fill: parent
                radius: 20
                color: "#e6121214"
                border.color: "#ffffff18"
                border.width: 1

                NumberAnimation on height {
                    from: 0
                    to: 520
                    duration: 250
                    easing.type: Easing.OutCubic
                }

                NumberAnimation on opacity {
                    from: 0.0
                    to: 1.0
                    duration: 200
                }

                // Pointer Arrow
                Rectangle {
                    width: 14
                    height: 14
                    rotation: 45
                    anchors.right: parent.right
                    anchors.rightMargin: 150
                    anchors.verticalCenter: parent.top
                    color: "#161618"
                    border.color: "#ffffff18"
                    border.width: 1
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Title Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰥔 INTERACTIVE CALENDAR"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#e2e8f0"
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 8
                            color: "#1e1e22"
                            Text { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 13; color: "#ff0055" }
                            MouseArea { anchors.fill: parent; onClicked: root.closeWidget() }
                        }
                    }

                    // Clock Header
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Text {
                            text: root.timeStr
                            font.pixelSize: 26
                            font.bold: true
                            color: "#f8fafc"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: root.dateStr
                            font.pixelSize: 12
                            color: "#94a3b8"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#ffffff15"
                    }

                    // Month Navigation Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: "#1e1e22"
                            Text { anchors.centerIn: parent; text: "◀"; font.pixelSize: 12; color: "#e2e8f0" }
                            MouseArea { anchors.fill: parent; onClicked: root.prevMonth() }
                        }

                        Text {
                            text: Qt.formatDateTime(new Date(root.displayYear, root.displayMonth, 1), "MMMM yyyy")
                            font.pixelSize: 14
                            font.bold: true
                            color: "#f8fafc"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            implicitWidth: 50
                            implicitHeight: 30
                            radius: 8
                            color: "#1e1e22"
                            Text { anchors.centerIn: parent; text: "Today"; font.pixelSize: 11; font.bold: true; color: "#10b981" }
                            MouseArea { anchors.fill: parent; onClicked: root.resetToday() }
                        }

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: "#1e1e22"
                            Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: 12; color: "#e2e8f0" }
                            MouseArea { anchors.fill: parent; onClicked: root.nextMonth() }
                        }
                    }

                    // Interactive Calendar Grid
                    MonthGrid {
                        id: grid
                        Layout.fillWidth: true
                        implicitHeight: 210
                        month: root.displayMonth
                        year: root.displayYear
                        locale: Qt.locale("en_US")

                        delegate: Rectangle {
                            implicitWidth: 38
                            implicitHeight: 32
                            radius: 8

                            property bool isSelected: (model.month === root.selMonth && model.year === root.selYear && model.day === root.selDay)
                            property string dayKey: root.getFormattedKey(model.year, model.month, model.day)
                            property bool hasBookmarks: Boolean(root.eventsData && root.eventsData[dayKey] && root.eventsData[dayKey].length > 0)

                            color: isSelected ? "#f8fafc" : (model.today ? "#ffffff20" : (model.isCurrentMonth ? "#1e1e22" : "transparent"))
                            border.color: isSelected ? "#f8fafc" : (hasBookmarks ? "#94a3b8" : "transparent")
                            border.width: (isSelected || hasBookmarks) ? 1 : 0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    text: model.day
                                    font.pixelSize: 11
                                    font.bold: model.today || isSelected
                                    color: isSelected ? "#09090b" : (model.today ? "#f8fafc" : (model.isCurrentMonth ? "#e2e8f0" : "#475569"))
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    visible: hasBookmarks && !isSelected
                                    text: "📌"
                                    font.pixelSize: 8
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selDay = model.day;
                                    root.selMonth = model.month;
                                    root.selYear = model.year;
                                    root.updateSelectedEvents();
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: "#ffffff15"
                    }

                    // Bookmarks & Notes Section Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "📌 BOOKMARKS (" + root.getFormattedKey(root.selYear, root.selMonth, root.selDay) + ")"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#cbd5e1"
                        }
                    }

                    // Input Row to Add Bookmark Note
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: 8
                            color: "#1e1e22"
                            border.color: "#ffffff15"

                            TextInput {
                                id: noteInput
                                anchors.fill: parent
                                anchors.margins: 8
                                font.pixelSize: 11
                                color: "#f8fafc"
                                selectByMouse: true
                                Text {
                                    text: "Add reminder note..."
                                    font.pixelSize: 11
                                    color: "#64748b"
                                    visible: !noteInput.text
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 65
                            implicitHeight: 32
                            radius: 8
                            color: "#f8fafc"

                            Text {
                                anchors.centerIn: parent
                                text: "+ Add"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#09090b"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (noteInput.text.trim().length > 0) {
                                        var k = root.getFormattedKey(root.selYear, root.selMonth, root.selDay);
                                        root.runEventsCmd(["python3", Quickshell.env("HOME") + "/.config/quickshell/widgets/clock/events.py", "add", k, noteInput.text.trim()]);
                                        noteInput.text = "";
                                    }
                                }
                            }
                        }
                    }

                    // Bookmarks List
                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 70
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.selectedEvents
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    radius: 6
                                    color: "#1e1e22"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 6

                                        Text { text: "📌"; font.pixelSize: 10 }
                                        Text {
                                            text: modelData
                                            font.pixelSize: 11
                                            color: "#f8fafc"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Rectangle {
                                            implicitWidth: 20
                                            implicitHeight: 20
                                            radius: 5
                                            color: "#ef444433"
                                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: "#ef4444" }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    var k = root.getFormattedKey(root.selYear, root.selMonth, root.selDay);
                                                    root.runEventsCmd(["python3", Quickshell.env("HOME") + "/.config/quickshell/widgets/clock/events.py", "delete", k, index.toString()]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: root.selectedEvents.length === 0
                                text: "No bookmarks for this date"
                                font.pixelSize: 11
                                color: "#64748b"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
