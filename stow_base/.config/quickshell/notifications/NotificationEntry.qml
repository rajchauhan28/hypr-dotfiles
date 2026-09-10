import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

// One row inside the shared card. Entries never draw their own background or
// border -- the card silhouette behind them is a single closed path, and a
// per-entry rectangle would break the illusion of one surface. Separation is
// the hairline drawn at the top of every entry but the first.
Item {
    id: entry

    required property var notif
    // Named entryIndex, not index: `index` is injected into delegates by the
    // Repeater, and a required property of that name collides with it.
    property int entryIndex: 0
    // Set by the parent so the topmost entry omits its divider.
    property bool showDivider: entryIndex > 0

    signal requestDismiss()

    // Entries collapse before they are actually dismissed, so the delegate has
    // to outlive the request. `closing` drives the collapse; the parent only
    // calls notif.dismiss() once the animation lands.
    property bool closing: false
    property bool hovered: hoverArea.containsMouse || actionsHover.containsMouse

    readonly property int dividerHeight: showDivider ? 1 : 0

    implicitWidth: parent ? parent.width : Theme.panelWidth
    width: implicitWidth

    // Collapsing to zero height is what makes the card shrink around the
    // remaining entries instead of leaving a gap.
    height: closing ? 0 : content.implicitHeight + dividerHeight
    opacity: closing ? 0 : 1
    clip: true

    Behavior on height {
        NumberAnimation { duration: Theme.animPanel; easing.type: Theme.easeOutExpo }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.animNormal }
    }

    // Fires once the collapse has finished so the row is gone before the
    // notification is closed on the bus.
    onHeightChanged: {
        if (closing && height < 0.5)
            entry.requestDismiss();
    }

    Rectangle {
        id: divider
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        height: entry.dividerHeight
        color: Theme.divider
        visible: entry.showDivider
    }

    // Slide each row in from the right edge. New rows arriving into an
    // already-open card get the same motion the card itself used.
    transform: Translate {
        id: rowSlide
        x: entry.width
    }

    Component.onCompleted: rowSlideIn.start()

    NumberAnimation {
        id: rowSlideIn
        target: rowSlide
        property: "x"
        to: 0
        duration: Theme.animSlide
        easing.type: Theme.easeOutExpo
    }

    // --- Criticality -------------------------------------------------------
    // Two ways in. The sender can mark a notification critical over D-Bus, and
    // the user can name words that promote one here. They are kept apart
    // because they earn different treatment: an app calling itself critical is
    // a claim (and a lot of apps overclaim -- wifi, bluetooth and browser chat
    // notifications all do), while a keyword the user typed is an instruction.
    readonly property bool senderCritical:
        notif.urgency === NotificationUrgency.Critical

    // App name is matched too, so "brave" or "networkmanager" pins everything
    // from one source without naming each message.
    readonly property string matchText:
        ((notif.appName || "") + " " + (notif.summary || "")
         + " " + (notif.body || "")).toLowerCase()

    readonly property bool keywordCritical: {
        var kw = Theme.criticalKeywords;
        if (!kw || kw.length === 0)
            return false;
        for (var i = 0; i < kw.length; i++) {
            var k = String(kw[i]).trim().toLowerCase();
            // A stray empty entry would otherwise match every notification,
            // since "".indexOf is always 0.
            if (k !== "" && entry.matchText.indexOf(k) !== -1)
                return true;
        }
        return false;
    }

    readonly property bool critical: entry.senderCritical || entry.keywordCritical

    // --- Auto expiry -------------------------------------------------------
    // A keyword match is the user saying "do not take this away", so it always
    // pins. A sender's own critical flag is honoured for timeoutCritical
    // seconds, or forever when that is set to 0.
    readonly property bool pinned:
        entry.keywordCritical
        || (entry.senderCritical && Theme.timeoutCritical <= 0)

    readonly property bool autoExpires: !entry.pinned

    readonly property int timeoutMs: {
        // Critical outranks the sender's own requested timeout: an app that
        // asks to be critical AND to vanish in 2s gets the critical dwell.
        if (entry.senderCritical)
            return Theme.timeoutCritical * 1000;
        if (notif.expireTimeout > 0)
            return Math.round(notif.expireTimeout * 1000);
        return (notif.urgency === NotificationUrgency.Low
                ? Theme.timeoutLow : Theme.timeoutNormal) * 1000;
    }

    Timer {
        id: expiryTimer
        interval: entry.timeoutMs
        // Hovering holds the notification: you are reading it.
        running: entry.autoExpires && !entry.closing && !entry.hovered
        repeat: false
        onTriggered: entry.closing = true
    }

    // Restart rather than resume on unhover, so a glance never leaves a
    // notification with 200ms left on the clock.
    onHoveredChanged: {
        if (!hovered && expiryTimer.running)
            expiryTimer.restart();
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // The spec's implicit default action, if the app declared one.
                for (var i = 0; i < entry.notif.actions.length; i++) {
                    if (entry.notif.actions[i].identifier === "default") {
                        entry.notif.actions[i].invoke();
                        return;
                    }
                }
            }
            entry.closing = true;
        }
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.topMargin: entry.dividerHeight
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.cardPadding
            Layout.rightMargin: Theme.cardPadding
            Layout.topMargin: Theme.cardPadding
            Layout.bottomMargin: Theme.cardPadding
            spacing: 12

            // --- Icon ---------------------------------------------------
            Item {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Theme.iconSize
                Layout.preferredHeight: Theme.iconSize

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: Theme.card
                    border.color: Theme.border
                    border.width: 1
                    visible: iconImg.status !== Image.Ready
                }

                Image {
                    id: iconImg
                    anchors.fill: parent
                    // `image` is the app's own pixmap/path and outranks the
                    // themed appIcon name when both are present.
                    source: {
                        if (entry.notif.image)
                            return entry.notif.image;
                        if (entry.notif.appIcon)
                            return Quickshell.iconPath(entry.notif.appIcon, true);
                        return "";
                    }
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.pixelSize: 17
                    color: Theme.textMuted
                    visible: iconImg.status !== Image.Ready
                }
            }

            // --- Text -----------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        // Shows for keyword-promoted entries too -- otherwise
                        // a pinned notification would look identical to one
                        // that is simply taking its time.
                        visible: entry.critical
                        Layout.alignment: Qt.AlignVCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.danger
                    }

                    Text {
                        Layout.fillWidth: true
                        text: entry.notif.summary || entry.notif.appName || "Notification"
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        visible: !!entry.notif.appName && !!entry.notif.summary
                        text: entry.notif.appName
                        font.pixelSize: 10
                        color: Theme.textMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: 90
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !!entry.notif.body
                    text: entry.notif.body
                    font.pixelSize: 12
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    maximumLineCount: Theme.bodyMaxLines
                    // Apps send limited HTML per the freedesktop spec.
                    textFormat: Text.StyledText
                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                }
            }
        }

        // --- Actions --------------------------------------------------
        Flow {
            id: actionRow
            Layout.fillWidth: true
            Layout.leftMargin: Theme.cardPadding
            Layout.rightMargin: Theme.cardPadding
            Layout.bottomMargin: visible ? Theme.cardPadding : 0
            spacing: 8
            visible: entry.notif.actions.length > 0
                     && !(entry.notif.actions.length === 1
                          && entry.notif.actions[0].identifier === "default")

            MouseArea {
                id: actionsHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Repeater {
                model: entry.notif.actions

                delegate: Rectangle {
                    required property var modelData
                    // The default action is the whole-row click, not a button.
                    visible: modelData.identifier !== "default"
                    width: visible ? actionLabel.implicitWidth + 22 : 0
                    height: visible ? 26 : 0
                    radius: Theme.radiusSmall
                    color: actionMouse.containsMouse ? Theme.cardHover : Theme.card
                    border.color: actionMouse.containsMouse ? Theme.accent : Theme.border
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: modelData.text || modelData.identifier
                        font.pixelSize: 11
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.invoke();
                            entry.closing = true;
                        }
                    }
                }
            }
        }
    }
}
