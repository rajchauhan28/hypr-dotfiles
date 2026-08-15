import QtQuick
import QtQuick.Layouts

Item {
    id: dash

    property var stats: ({})
    property var weather: ({})
    property date now: new Date()
    property var updates: ({})
    property bool updatesBusy: false
    property var wallpapers: ({})
    property var bookmarks: ({})
    property var holidays: ({})
    property bool holidaysComplete: false

    signal refreshUpdates()
    signal openTerminal(string cmd)
    signal applyWallpaper(string path)
    signal addBookmark(string dateKey, string text)
    signal deleteBookmark(string dateKey, int index)
    signal needHolidays(int year)

    // Browsed month, independent of the clock. Reset to today whenever the
    // panel is reopened so it never comes back parked on a stale month.
    property int calMonth: dash.now.getMonth()
    property int calYear: dash.now.getFullYear()
    property string selectedKey: dash.dateKey(dash.now.getFullYear(),
                                              dash.now.getMonth(),
                                              dash.now.getDate())

    readonly property int today: dash.now.getDate()
    readonly property int todayMonth: dash.now.getMonth()
    readonly property int todayYear: dash.now.getFullYear()

    function dateKey(y, m, d) {
        return y + "-" + (m + 1 < 10 ? "0" : "") + (m + 1) + "-" + (d < 10 ? "0" : "") + d;
    }

    function shiftMonth(delta) {
        var m = dash.calMonth + delta;
        var y = dash.calYear;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        dash.calMonth = m;
        dash.calYear = y;
        dash.needHolidays(y);
    }

    function shiftYear(delta) {
        dash.calYear += delta;
        dash.needHolidays(dash.calYear);
    }

    function goToday() {
        dash.calMonth = dash.todayMonth;
        dash.calYear = dash.todayYear;
        dash.selectedKey = dash.dateKey(dash.todayYear, dash.todayMonth, dash.today);
        dash.needHolidays(dash.calYear);
    }

    readonly property var monthNames: ["January", "February", "March", "April",
        "May", "June", "July", "August", "September", "October", "November", "December"]

    function holidayFor(key) {
        return (dash.holidays && dash.holidays[key]) ? dash.holidays[key] : "";
    }

    function notesFor(key) {
        return (dash.bookmarks && dash.bookmarks[key]) ? dash.bookmarks[key] : [];
    }

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    // Cells for a Mon-first 6x7 grid, including the greyed-out spill days.
    function calendarCells() {
        var cells = [];
        var first = new Date(dash.calYear, dash.calMonth, 1).getDay(); // 0 = Sun
        var lead = (first + 6) % 7;                                    // Mon-first
        var dim = daysInMonth(dash.calYear, dash.calMonth);
        var prevDim = daysInMonth(dash.calYear, dash.calMonth - 1);

        for (var i = lead - 1; i >= 0; i--)
            cells.push({ day: prevDim - i, current: false, key: "" });
        for (var d = 1; d <= dim; d++)
            cells.push({ day: d, current: true, key: dash.dateKey(dash.calYear, dash.calMonth, d) });
        var tail = 42 - cells.length;
        for (var n = 1; n <= tail; n++)
            cells.push({ day: n, current: false, key: "" });
        return cells;
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // ---- Left column: weather over clock + calendar ----
        ColumnLayout {
            // Nested layouts default to fillWidth: true, which would let a long
            // weather location string starve the middle column. Pin it instead.
            Layout.fillWidth: false
            Layout.preferredWidth: 380
            Layout.maximumWidth: 380
            Layout.fillHeight: true
            spacing: Theme.gap

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 110

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    spacing: 14

                    Text {
                        text: dash.weather.icon || "󰖙"
                        font.pixelSize: 34
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: dash.weather.temp !== undefined ? dash.weather.temp + "°C" : "--°"
                            font.pixelSize: 30
                            font.bold: true
                            color: Theme.textPrimary
                        }
                        Text {
                            text: dash.weather.desc || "No data"
                            font.pixelSize: 11
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.maximumWidth: 130
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 110

                        Text {
                            // Only the first component; wttr.in returns the full
                            // administrative path, which is far too long here.
                            text: (dash.weather.location || "").split(",")[0]
                            font.pixelSize: 10
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            Layout.maximumWidth: 110
                            Layout.alignment: Qt.AlignRight
                        }
                        Text {
                            text: dash.weather.humidity !== undefined ? "󰖎 " + dash.weather.humidity + "%" : ""
                            font.pixelSize: 10
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    spacing: 12

                    // Clock across the top — the column is tall and narrow now,
                    // so stacking beats sitting beside the month grid.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: Qt.formatDateTime(dash.now, "HH:mm")
                            font.pixelSize: 44
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: Qt.formatDateTime(dash.now, "dddd")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textSecondary
                            }
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: Qt.formatDateTime(dash.now, "d MMMM yyyy")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                    }

                    // ---- Month / year navigation ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { glyph: "\u00ab", act: "year-",  tip: "previous year" },
                                { glyph: "\u2039", act: "month-", tip: "previous month" }
                            ]
                            delegate: Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 7
                                color: navMouse.containsMouse ? Theme.cardHover : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph
                                    font.pixelSize: 13
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.act === "year-" ? dash.shiftYear(-1)
                                                                         : dash.shiftMonth(-1)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: dash.monthNames[dash.calMonth] + " " + dash.calYear
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        // Jump back to the current month; only offered when the
                        // browsed month is not already today's.
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 7
                            visible: dash.calMonth !== dash.todayMonth || dash.calYear !== dash.todayYear
                            color: todayMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "\u25cf"
                                font.pixelSize: 9
                                color: Theme.accent
                            }

                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dash.goToday()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { glyph: "\u203a", act: "month+" },
                                { glyph: "\u00bb", act: "year+" }
                            ]
                            delegate: Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 7
                                color: nav2Mouse.containsMouse ? Theme.cardHover : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph
                                    font.pixelSize: 13
                                    color: Theme.textSecondary
                                }

                                MouseArea {
                                    id: nav2Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.act === "year+" ? dash.shiftYear(1)
                                                                         : dash.shiftMonth(1)
                                }
                            }
                        }
                    }

                    // Month grid. Weekday headers and day numbers share ONE
                    // GridLayout so the columns line up — two stacked grids
                    // size their columns independently and drift apart.
                    GridLayout {
                        id: cal
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumWidth: 999      // full column width now
                        Layout.alignment: Qt.AlignHCenter
                        columns: 7
                        columnSpacing: 0
                        rowSpacing: 0

                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1   // equal share for every column
                                Layout.preferredHeight: 20

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.textMuted
                                }
                            }
                        }

                        Repeater {
                            model: dash.calendarCells()
                            delegate: Item {
                                id: cell
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1

                                readonly property bool isToday: modelData.current
                                                                && modelData.day === dash.today
                                                                && dash.calMonth === dash.todayMonth
                                                                && dash.calYear === dash.todayYear
                                readonly property bool isSelected: modelData.current
                                                                   && modelData.key === dash.selectedKey
                                readonly property string holiday: modelData.current
                                                                  ? dash.holidayFor(modelData.key) : ""
                                readonly property int noteCount: modelData.current
                                                                 ? dash.notesFor(modelData.key).length : 0

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height, 32)
                                    height: width
                                    radius: width / 2
                                    color: cell.isToday ? Theme.accent
                                         : (cell.isSelected ? Theme.cardHover
                                         : (dayMouse.containsMouse ? "#14ffffff" : "transparent"))
                                    border.color: cell.isSelected && !cell.isToday
                                                  ? Theme.borderStrong : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: 12
                                    font.bold: cell.isToday || cell.holiday !== ""
                                    color: cell.isToday ? "#0a0a0f"
                                         : (!modelData.current ? Theme.textFaint
                                         : (cell.holiday !== "" ? Theme.danger : Theme.textSecondary))
                                }

                                // Markers: holiday (left) and bookmarks (right).
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    spacing: 2

                                    Rectangle {
                                        visible: cell.holiday !== ""
                                        width: 4; height: 4; radius: 2
                                        color: cell.isToday ? "#0a0a0f" : Theme.danger
                                    }
                                    Rectangle {
                                        visible: cell.noteCount > 0
                                        width: 4; height: 4; radius: 2
                                        color: cell.isToday ? "#0a0a0f" : Theme.good
                                    }
                                }

                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData.current
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dash.selectedKey = modelData.key
                                }
                            }
                        }
                    }

                    // ---- Selected day: holiday + bookmarks ----
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: dash.selectedKey
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.1
                                color: Theme.textMuted
                            }
                            Text {
                                text: dash.holidayFor(dash.selectedKey)
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.danger
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Repeater {
                            model: dash.notesFor(dash.selectedKey)
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "\u2022"
                                    font.pixelSize: 11
                                    color: Theme.good
                                }
                                Text {
                                    text: modelData
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    radius: 5
                                    color: delMouse.containsMouse ? Theme.danger : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u00d7"
                                        font.pixelSize: 11
                                        color: delMouse.containsMouse ? "#ffffff" : Theme.textFaint
                                    }

                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: dash.deleteBookmark(dash.selectedKey, index)
                                    }
                                }
                            }
                        }

                        // Add a bookmark. The panel takes keyboard focus on
                        // demand, so this field only grabs input once clicked.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Theme.radiusSmall
                            color: Theme.cardAlt
                            border.color: noteInput.activeFocus ? Theme.borderStrong : Theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 4
                                spacing: 4

                                TextInput {
                                    id: noteInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 11
                                    color: Theme.textPrimary
                                    clip: true
                                    selectByMouse: true

                                    Text {
                                        text: "Add a bookmark\u2026"
                                        font.pixelSize: 11
                                        color: Theme.textFaint
                                        visible: noteInput.text === "" && !noteInput.activeFocus
                                    }

                                    onAccepted: {
                                        if (text.trim() !== "") {
                                            dash.addBookmark(dash.selectedKey, text.trim());
                                            text = "";
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    radius: 7
                                    color: addMouse.containsMouse ? Theme.accent : Theme.card

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: addMouse.containsMouse ? "#0a0a0f" : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: addMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: noteInput.accepted()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: !dash.holidaysComplete
                            text: "Fixed-date holidays only \u2014 install the `holidays` package for festivals"
                            font.pixelSize: 8
                            color: Theme.textFaint
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // ---- Middle column: system identity + vitals ----
        Card {
            Layout.fillWidth: true
            Layout.minimumWidth: 300
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.cardPadding
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap

                    Rectangle {
                        implicitWidth: 64
                        implicitHeight: 64
                        radius: 32
                        color: Theme.cardAlt
                        border.color: Theme.borderStrong
                        border.width: 1
                        clip: true

                        Image {
                            id: dashboardProfileImage
                            anchors.fill: parent
                            anchors.margins: Theme.hasCustomProfileIcon ? 0 : 10
                            source: Theme.profileIcon
                            fillMode: Theme.hasCustomProfileIcon
                                      ? Image.PreserveAspectCrop
                                      : Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(128, 128)
                            visible: source.toString() !== "" && status !== Image.Error
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.pixelSize: 30
                            color: Theme.textMuted
                            visible: Theme.profileIcon === ""
                                     || dashboardProfileImage.status === Image.Error
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: Theme.username
                            font.pixelSize: 17
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "󰌢  " + (dash.stats.host || "") + "  ·  " + (dash.stats.kernel || "")
                            font.pixelSize: 11
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "󰅐  up " + (dash.stats.uptime || "--")
                            font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                }

                Meter {
                    Layout.fillWidth: true
                    label: "CPU"
                    value: dash.stats.cpu || 0
                    valueText: (dash.stats.cpu || 0) + "%  ·  " + (dash.stats.temp || 0) + "°C"
                }

                Meter {
                    Layout.fillWidth: true
                    label: "Memory"
                    value: dash.stats.mem || 0
                    valueText: (dash.stats.memUsed || 0) + " / " + (dash.stats.memTotal || 0) + " GiB"
                }

                Meter {
                    Layout.fillWidth: true
                    label: "Swap"
                    value: dash.stats.swap || 0
                }

                Meter {
                    Layout.fillWidth: true
                    label: "Disk  /"
                    value: dash.stats.disk || 0
                    valueText: (dash.stats.diskUsed || 0) + " / " + (dash.stats.diskTotal || 0) + " GB"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 1
                    color: Theme.border
                }

                WallpaperPane {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    info: dash.wallpapers
                    onApply: p => dash.applyWallpaper(p)
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: dash.stats.battery !== undefined && dash.stats.battery.present

                    Text {
                        text: {
                            var b = dash.stats.battery || {};
                            if (b.status === "Charging")
                                return "󰂄";
                            var c = b.capacity || 0;
                            if (c > 80) return "󰁹";
                            if (c > 55) return "󰂀";
                            if (c > 30) return "󰁾";
                            if (c > 12) return "󰁻";
                            return "󰁺";
                        }
                        font.pixelSize: 14
                        color: {
                            var b = dash.stats.battery || {};
                            if (b.status === "Charging")
                                return Theme.good;
                            return (b.capacity || 0) <= 15 ? Theme.danger : Theme.textSecondary;
                        }
                    }
                    Text {
                        text: (dash.stats.battery ? dash.stats.battery.capacity : 0) + "%  "
                              + (dash.stats.battery ? dash.stats.battery.status : "")
                        font.pixelSize: 10
                        color: Theme.textMuted
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "load " + (dash.stats.load !== undefined ? dash.stats.load : "--")
                        font.pixelSize: 10
                        color: Theme.textMuted
                    }
                }
            }
        }

        // ---- Right column: player over system updates ----
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            Layout.fillHeight: true
            spacing: Theme.gap

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                DashboardMediaCard {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 84

                PowerCard {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 210

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.cardPadding
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "UPDATES"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 7
                            color: refreshMouse.containsMouse ? Theme.cardHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: dash.updatesBusy ? "󰦖" : "󰑐"
                                font.pixelSize: 12
                                color: dash.updatesBusy ? Theme.textFaint : Theme.textSecondary
                            }

                            MouseArea {
                                id: refreshMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!dash.updatesBusy) dash.refreshUpdates()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: dash.updates.total !== undefined ? dash.updates.total : "–"
                            font.pixelSize: 34
                            font.bold: true
                            color: (dash.updates.total || 0) > 0 ? Theme.textPrimary : Theme.textMuted
                        }
                        Text {
                            text: (dash.updates.total === 1 ? "package" : "packages") + "\npending"
                            font.pixelSize: 10
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Per-source breakdown
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 6

                        Repeater {
                            model: [
                                { label: "repo", value: dash.updates.repo },
                                { label: "aur", value: dash.updates.aur },
                                { label: "flatpak", value: dash.updates.flatpak }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: Theme.radiusSmall
                                color: Theme.cardAlt
                                border.color: Theme.border
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: -1

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.value !== undefined ? modelData.value : "–"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: (modelData.value || 0) > 0 ? Theme.textPrimary : Theme.textFaint
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: 8
                                        color: Theme.textMuted
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Runs the upgrade in a real terminal so password
                        // prompts and conflict questions stay interactive.
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.radiusSmall
                            color: updMouse.containsMouse ? "#ffffff" : Theme.accent
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰚰  Update"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#0a0a0f"
                            }

                            MouseArea {
                                id: updMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dash.openTerminal("yay -Syu; echo; echo 'Press Enter to close…'; read")
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.radiusSmall
                            color: rateMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                            border.color: Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰓅  Rate & Update"
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: rateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dash.openTerminal("rate-mirrors --protocol=https arch | sudo tee /etc/pacman.d/mirrorlist && yay -Syu; echo; echo 'Press Enter to close…'; read")
                            }
                        }

                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 32
                            radius: Theme.radiusSmall
                            color: termMouse.containsMouse ? Theme.cardHover : Theme.cardAlt
                            border.color: Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                // MDI range renders in this font; the older
                                // nf-fa terminal glyph came out as a blank box.
                                text: "󰆍"
                                font.pixelSize: 15
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: termMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dash.openTerminal("")
                            }
                        }
                    }
                }
            }
        }
    }
}
