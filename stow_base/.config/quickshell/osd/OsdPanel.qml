import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../common" as Common

// Bottom-centre OSD pill for volume, brightness and mute toggles. Takes no
// input, so the layer surface sits on Overlay with no keyboard focus and no
// exclusive zone. State is driven over IPC (target "osd") so hyprland.conf
// binds call this directly rather than going through the sidepanel.
Scope {
    id: root

    // kind: "volume" | "brightness" | "mic"
    property string kind: "volume"
    property int value: 0
    property bool muted: false
    property bool shown: false

    Timer {
        id: hideTimer
        interval: Theme.visibleMs
        repeat: false
        onTriggered: root.shown = false
    }

    function pop(k, v, m) {
        root.kind = k;
        root.value = Math.max(0, Math.min(100, Math.round(v)));
        root.muted = !!m;
        root.shown = true;
        hideTimer.restart();
    }

    // Each driver kind owns one Process that both mutates and reads back in a
    // single shell invocation. Chaining mutate && read in one `sh -c` avoids
    // a race between the setter and the getter and keeps the OSD showing the
    // post-change value, not the pre-change one.
    function stepVolume(delta) {
        var step = Math.abs(delta) * 5;
        var sign = delta >= 0 ? "+" : "-";
        sinkProc.command = ["sh", "-c",
            "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ " + step + "%" + sign +
            " && wpctl get-volume @DEFAULT_AUDIO_SINK@"];
        sinkProc.running = true;
    }

    function stepBrightness(delta) {
        var step = Math.abs(delta) * 5;
        var sign = delta >= 0 ? "+" : "-";
        brightProc.command = ["sh", "-c",
            "brightnessctl -q s " + step + "%" + sign +
            " && brightnessctl -m | cut -d, -f4 | tr -d '%'"];
        brightProc.running = true;
    }

    function toggleSink() {
        sinkProc.command = ["sh", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            + " && wpctl get-volume @DEFAULT_AUDIO_SINK@"];
        sinkProc.running = true;
    }

    function toggleSource() {
        micProc.command = ["sh", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            + " && wpctl get-volume @DEFAULT_AUDIO_SOURCE@"];
        micProc.running = true;
    }

    // wpctl's "Volume: 0.42 [MUTED]" output is the same shape for sink and
    // source, so both share one parser.
    function _parseWpctl(t, kind) {
        var m = (t || "").match(/Volume:\s*([0-9.]+)/);
        var pct = m ? Math.round(parseFloat(m[1]) * 100) : 0;
        root.pop(kind, pct, /MUTED/.test(t));
    }

    Process {
        id: sinkProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseWpctl(text, "volume")
        }
    }

    Process {
        id: micProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parseWpctl(text, "mic")
        }
    }

    Process {
        id: brightProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var pct = parseInt((text || "").trim(), 10);
                if (!isFinite(pct)) pct = 0;
                root.pop("brightness", pct, false);
            }
        }
    }

    IpcHandler {
        target: "osd"
        function volume(delta: int): void      { root.stepVolume(delta); }
        function brightness(delta: int): void  { root.stepBrightness(delta); }
        function muteSink(): void              { root.toggleSink(); }
        function muteSource(): void            { root.toggleSource(); }
    }

    PanelWindow {
        id: win

        anchors { bottom: true }
        exclusiveZone: 0
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-osd"

        implicitWidth: Theme.panelWidth
        implicitHeight: Theme.panelHeight + Theme.bottomMargin

        // The pill is click-through: let the compositor route taps straight to
        // whatever is underneath, same as the notification stack does.
        mask: Region {}

        // Hidden until shown; the fade/slide is driven by opacity + y offset.
        Item {
            id: pill
            width: Theme.panelWidth
            height: Theme.panelHeight
            x: 0
            y: root.shown ? 0 : 12
            opacity: root.shown ? 1.0 : 0.0

            Behavior on y       { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutQuint } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusPanel
                color: Theme.panelBg
                border.width: 1
                border.color: Theme.panelBorder

                Common.GlassRim {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: Theme.glass
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Icon glyph. Nerd Font ranges from the leftbar font stack.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSize
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.iconSize
                    color: Theme.textPrimary
                    text: {
                        if (root.kind === "brightness") return "󰃞";
                        if (root.kind === "mic")        return root.muted ? "󰍭" : "󰍬";
                        return root.muted ? "󰝟" : (root.value > 50 ? "󰕾" : root.value > 0 ? "󰖀" : "󰸈");
                    }
                }

                Item {
                    width: parent.width - Theme.iconSize - 12 - percent.width - 12
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Theme.trackHeight
                        radius: height / 2
                        color: Theme.trackBg

                        Rectangle {
                            width: parent.width * (root.muted ? 0 : (root.value / 100))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                    }
                }

                Text {
                    id: percent
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.muted && root.kind !== "brightness" ? "mute" : (root.value + "%")
                    font.pixelSize: 14
                    color: Theme.textPrimary
                    width: 48
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
