import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    property string currentPassword: ""
    property bool authInProgress: false
    property bool authFailed: false
    readonly property string sessionUser: Quickshell.env("USER")
    property var profiles: Theme.users
    property int selectedProfileIndex: 0
    readonly property var selectedProfile: profiles.length > selectedProfileIndex
                                           ? profiles[selectedProfileIndex] : ({
                                               "username": sessionUser,
                                               "name": sessionUser,
                                               "icon": "",
                                               "current": true
                                           })
    readonly property string selectedUser: selectedProfile.username
    property real carouselOffset: 0
    property real sideProfilesOpacity: 1
    property int pendingProfileIndex: 0
    property bool carouselBusy: false
    readonly property real profileSpacing: 108

    signal profileChanged()

    onCurrentPasswordChanged: authFailed = false

    function profileIcon(profile) {
        if (profile.current && Theme.lockIcon !== "")
            return Theme.lockIcon;
        if (profile.icon && profile.icon !== "")
            return profile.icon;
        return Theme.osIcon;
    }

    function profileHasPhoto(profile) {
        return (profile.current && Theme.lockIcon !== "")
                || (profile.icon && profile.icon !== "");
    }

    function profileSlot(index) {
        if (profiles.length === 0)
            return 0;
        return (index - selectedProfileIndex + profiles.length) % profiles.length;
    }

    function beginProfileSelection(index, animation) {
        if (index === selectedProfileIndex || index < 0 || index >= profiles.length
                || carouselBusy || authInProgress)
            return;

        currentPassword = "";
        authFailed = false;
        pendingProfileIndex = index;
        carouselBusy = true;
        animation.to = profileSlot(index) * profileSpacing;
        animation.restart();
    }

    function completeProfileSelection() {
        var index = pendingProfileIndex;
        if (index < 0 || index >= profiles.length) {
            carouselBusy = false;
            return;
        }

        // Keep the model and delegates intact. Only the logical center changes,
        // so image textures are never destroyed/recreated at the end of a slide.
        selectedProfileIndex = index;
        carouselOffset = 0;
        pendingProfileIndex = index;
        profileChanged();
    }

    function tryUnlock() {
        if (selectedUser !== sessionUser || currentPassword === "" || authInProgress)
            return;

        authFailed = false;
        authInProgress = true;
        pam.start();
    }

    function switchUser() {
        if (selectedUser === sessionUser || authInProgress)
            return;
        authFailed = false;
        authInProgress = true;
        switchUserProc.running = true;
    }

    PamContext {
        id: pam
        // Only the owner may unlock this session. Other profiles are handed
        // to SDDM below so one local account can never unlock another's desktop.
        user: root.sessionUser
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired)
                respond(root.currentPassword);
        }

        onCompleted: result => {
            root.authInProgress = false;

            if (result === PamResult.Success) {
                root.currentPassword = "";
                sessionLock.locked = false;
                Qt.quit();
            } else {
                root.currentPassword = "";
                root.authFailed = true;
            }
        }

        onError: error => {
            root.currentPassword = "";
            root.authInProgress = false;
            root.authFailed = true;
            console.warn("PAM authentication error:", PamError.toString(error));
        }
    }

    Process {
        id: switchUserProc
        command: ["bash", "/home/reign/.config/quickshell/lock/switch-user.sh"]
        onExited: code => {
            root.authInProgress = false;
            if (code !== 0)
                root.authFailed = true;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            color: "#101014"

            Rectangle {
                anchors.fill: parent
                color: "#101014"

                Item {
                    id: liveBackground
                    anchors.fill: parent
                    // Render the blur from the actual image/video texture. As a
                    // layer effect this is continuously refreshed by video
                    // frames instead of blurring a one-time screenshot.
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.72
                        blurMax: 48
                        blurMultiplier: 1.0
                        autoPaddingEnabled: false
                        saturation: -0.08
                    }

                    Image {
                        anchors.fill: parent
                        source: !Theme.backgroundIsVideo ? Theme.backgroundSource : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: source.toString() !== ""
                    }

                    VideoOutput {
                        id: backgroundVideo
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                        visible: Theme.backgroundIsVideo && Theme.backgroundSource !== ""
                    }

                    MediaPlayer {
                        id: backgroundPlayer
                        source: Theme.backgroundIsVideo ? Theme.backgroundSource : ""
                        videoOutput: backgroundVideo
                        autoPlay: true
                        loops: MediaPlayer.Infinite

                        onSourceChanged: {
                            if (source.toString() !== "")
                                play();
                        }
                        onMediaStatusChanged: {
                            if (mediaStatus === MediaPlayer.LoadedMedia
                                    || mediaStatus === MediaPlayer.BufferedMedia)
                                play();
                        }
                        onErrorOccurred: (error, message) =>
                            console.warn("Lockscreen video error:", error, message)
                    }

                    // Some FFmpeg/hardware-decoder combinations expose the
                    // first frame before transitioning to PlayingState. Keep
                    // nudging the silent background player until it advances.
                    Timer {
                        running: Theme.backgroundIsVideo
                                 && Theme.backgroundSource !== ""
                        repeat: true
                        interval: 1000
                        onTriggered: {
                            if (backgroundPlayer.playbackState
                                    !== MediaPlayer.PlayingState)
                                backgroundPlayer.play();
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#42000000"
                }

                // Kept as an uninstantiated fallback while this theme is
                // iterated; it cannot take focus or allocate duplicate images.
                Component {
                    id: legacyLayout

                    ColumnLayout {
                        visible: false
                        enabled: false
                        anchors.centerIn: parent
                    spacing: 18

                    // The current profile occupies the center slot. Other
                    // accounts wait to its right, dimmed and smaller. Clicking
                    // one slides the row left and rotates that account into
                    // the center without exposing profiles on the left.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 520
                        Layout.preferredHeight: 138
                        clip: true

                        NumberAnimation {
                            id: profileSlide
                            target: root
                            property: "carouselOffset"
                            duration: 430
                            easing.type: Easing.OutCubic
                            onStopped: sideProfilesFadeOut.restart()
                        }

                        NumberAnimation {
                            id: sideProfilesFadeOut
                            target: root
                            property: "sideProfilesOpacity"
                            to: 0
                            duration: 100
                            onStopped: {
                                root.completeProfileSelection();
                                sideProfilesFadeIn.restart();
                            }
                        }

                        NumberAnimation {
                            id: sideProfilesFadeIn
                            target: root
                            property: "sideProfilesOpacity"
                            to: 1
                            duration: 180
                            onStopped: root.carouselBusy = false
                        }

                        Repeater {
                            model: root.profiles

                            delegate: Item {
                                id: profileDelegate

                                required property var modelData
                                required property int index

                                readonly property bool active:
                                    index === (root.carouselBusy
                                               ? root.pendingProfileIndex
                                               : root.selectedProfileIndex)
                                property real emphasisOpacity: active ? 1.0 : 0.46

                                width: 128
                                height: 128
                                x: parent.width / 2
                                   + root.profileSlot(index) * root.profileSpacing
                                   - root.carouselOffset - width / 2
                                y: 5
                                scale: active ? 1.0 : 0.72
                                opacity: emphasisOpacity
                                         * (active ? 1.0 : root.sideProfilesOpacity)

                                Behavior on scale {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }
                                Behavior on emphasisOpacity {
                                    NumberAnimation { duration: 180 }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#68101014"
                                    border.color: profileDelegate.active
                                                  ? "#f8fafc" : "#70ffffff"
                                    border.width: profileDelegate.active ? 3 : 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: root.profileHasPhoto(profileDelegate.modelData)
                                                         ? 0 : 11
                                        source: root.profileIcon(profileDelegate.modelData)
                                        fillMode: root.profileHasPhoto(profileDelegate.modelData)
                                                  ? Image.PreserveAspectCrop
                                                  : Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: source.toString() !== ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰌾"
                                        font.pixelSize: 58
                                        color: Theme.textMuted
                                        visible: root.profileIcon(profileDelegate.modelData) === ""
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.carouselBusy && !root.authInProgress
                                    hoverEnabled: true
                                    cursorShape: index === root.selectedProfileIndex
                                                 ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: root.beginProfileSelection(
                                                   profileDelegate.index, profileSlide)
                                }
                            }
                        }
                    }

                    // Welcome Text
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Welcome, " + root.selectedProfile.name
                        font.pixelSize: 24
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Sign in as " + root.selectedUser + "  ·  " + Theme.osName
                        font.pixelSize: 12
                        color: Theme.textSecondary
                    }

                    // Password Input Box
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 260
                        height: 48
                        visible: root.selectedUser === root.sessionUser
                        radius: 24
                        color: "#8a101014"
                        border.color: root.authFailed ? Theme.danger : (pwdInput.activeFocus ? Theme.accent : "transparent")
                        border.width: 2

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: pwdInput
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 18
                            color: "transparent"
                            selectionColor: "transparent"
                            selectedTextColor: "transparent"
                            echoMode: TextInput.NoEcho
                            inputMethodHints: Qt.ImhSensitiveData
                            clip: true
                            cursorVisible: false
                            focus: true
                            enabled: !root.authInProgress

                            onTextChanged: root.currentPassword = text

                            onAccepted: root.tryUnlock()

                            Connections {
                                target: root
                                function onCurrentPasswordChanged() {
                                    if (pwdInput.text !== root.currentPassword)
                                        pwdInput.text = root.currentPassword;
                                }
                                function onProfileChanged() {
                                    pwdInput.forceActiveFocus();
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Password"
                                font.pixelSize: 16
                                color: Theme.textMuted
                                visible: pwdInput.text.length === 0 && !pwdInput.activeFocus
                            }
                        }

                        Item {
                            id: passwordDots

                            anchors.centerIn: parent
                            width: 220
                            height: 20

                            readonly property int dotCount:
                                Math.min(root.currentPassword.length, 16)
                            readonly property real dotStep: 17

                            Repeater {
                                // Keep every delegate alive. Changing the model
                                // count recreated dot items and caused the flash
                                // at the end of their entry animation.
                                model: 16

                                delegate: Text {
                                    id: passwordDot

                                    required property int index
                                    readonly property bool entered:
                                        index < passwordDots.dotCount

                                    width: 14
                                    height: 18
                                    text: "󰫣"
                                    font.pixelSize: 13
                                    color: "#f8fafc"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    x: passwordDots.width / 2
                                       + (index - (passwordDots.dotCount - 1) / 2)
                                         * passwordDots.dotStep
                                       - width / 2
                                    y: (passwordDots.height - height) / 2
                                    opacity: entered ? 1 : 0
                                    scale: entered ? 1 : 0.55

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 190
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 130 }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 170
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 260
                        height: 48
                        radius: 24
                        visible: root.selectedUser !== root.sessionUser
                        color: switchMouse.containsMouse ? "#a018181d" : "#8a101014"
                        border.color: Theme.accent
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.authInProgress
                                  ? "Opening user switcher…"
                                  : "Switch to " + root.selectedProfile.name
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: switchMouse
                            anchors.fill: parent
                            enabled: !root.authInProgress
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchUser()
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.selectedUser === root.sessionUser
                              ? "Authentication failed"
                              : "Unable to open the user switcher"
                        font.pixelSize: 14
                        color: Theme.danger
                        opacity: root.authFailed ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    }
                }

                FuturisticLock {
                    anchors.fill: parent
                    controller: root
                }
            }
        }
    }
}
