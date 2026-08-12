import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ColumnLayout {
    id: pane

    // compact = dashboard sidebar version; full = the Media tab.
    property bool compact: false

    spacing: compact ? 8 : 12

    Text {
        visible: !pane.compact
        text: "NOW PLAYING"
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        color: Theme.textMuted
    }

    // Album art as a spinning record. The circle is a MultiEffect mask, NOT
    // `clip` on a rounded Rectangle -- clip is rectangular in Qt, so clipping a
    // rotating platter produced a rotating *square*.
    Item {
        id: disc

        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Math.max(pane.compact ? 92 : 120,
                                Math.min(pane.width - 8, pane.height * (pane.compact ? 0.42 : 0.46)))
        implicitHeight: implicitWidth
        width: implicitWidth
        height: implicitHeight

        property real spin: 0
        property real spinVel: 0

        // Driven by a timer rather than a looping animation so that pausing
        // coasts to a stop and resuming picks up from the current angle -- an
        // Animator restarted from 0 snaps the artwork visibly.
        Timer {
            interval: 33
            repeat: true
            running: pane.visible && (MediaService.playing || disc.spinVel > 0.02)
            onTriggered: {
                var target = MediaService.playing ? 1.2 : 0.0;
                disc.spinVel += (target - disc.spinVel) * (MediaService.playing ? 0.22 : 0.05);
                disc.spin = (disc.spin + disc.spinVel) % 360;
            }
        }

        // Circumference Wave Visualizer surrounding the rotating circular album image
        Canvas {
            id: waveCanvas
            anchors.centerIn: parent
            width: disc.width + (pane.compact ? 24 : 36)
            height: width
            z: -1

            property real wavePhase: 0

            Timer {
                interval: 30
                repeat: true
                running: pane.visible && (MediaService.playing || MediaService.bass > 0.01)
                onTriggered: {
                    waveCanvas.wavePhase += 0.07;
                    waveCanvas.requestPaint();
                }
            }

            Connections {
                target: MediaService
                function onBandsChanged() {
                    waveCanvas.requestPaint();
                }
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var cx = width / 2;
                var cy = height / 2;
                var rBase = (disc.width / 2) + 2;
                var maxWaveH = pane.compact ? 6 : 10;
                var points = 80;
                var bands = MediaService.bands;
                var numBands = bands ? bands.length : 0;
                var bass = MediaService.bass || 0;
                var glowCol = MediaService.glow ? MediaService.glow.toString() : "#e4e4e7";

                ctx.save();

                // 1. Draw Outer Glowing Smooth Liquid Wave Ring
                ctx.beginPath();
                for (var i = 0; i <= points; i++) {
                    var angle = (i / points) * Math.PI * 2;
                    var bIdx = numBands > 0 ? Math.floor((i / points) * numBands) % numBands : 0;
                    var bandVal = numBands > 0 ? (bands[bIdx] / 100.0) : 0;
                    
                    var waveSine = Math.sin(angle * 5 + waveCanvas.wavePhase * 1.8) * 0.4 
                                 + Math.cos(angle * 3 - waveCanvas.wavePhase * 1.2) * 0.3;
                    var disp = (bandVal * 0.75 + waveSine + bass * 0.35) * maxWaveH;
                    var r = rBase + Math.max(1, disp);
                    var x = cx + r * Math.cos(angle);
                    var y = cy + r * Math.sin(angle);

                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.strokeStyle = glowCol;
                ctx.lineWidth = pane.compact ? 2.0 : 2.5;
                ctx.globalAlpha = MediaService.playing ? 0.9 : 0.4;
                ctx.stroke();

                // 2. Draw Secondary Accent Wave Ring (Out of phase for 3D fluid effect)
                ctx.beginPath();
                for (var j = 0; j <= points; j++) {
                    var angle2 = (j / points) * Math.PI * 2;
                    var bIdx2 = numBands > 0 ? Math.floor(((j + points / 4) / points) * numBands) % numBands : 0;
                    var bandVal2 = numBands > 0 ? (bands[bIdx2] / 100.0) : 0;
                    
                    var waveSine2 = Math.cos(angle2 * 6 - waveCanvas.wavePhase * 2.2) * 0.35
                                  + Math.sin(angle2 * 4 + waveCanvas.wavePhase * 1.5) * 0.25;
                    var disp2 = (bandVal2 * 0.6 + waveSine2 + bass * 0.25) * (maxWaveH * 0.75);
                    var r2 = rBase + Math.max(0.5, disp2);
                    var x2 = cx + r2 * Math.cos(angle2);
                    var y2 = cy + r2 * Math.sin(angle2);

                    if (j === 0) ctx.moveTo(x2, y2);
                    else ctx.lineTo(x2, y2);
                }
                ctx.closePath();
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = pane.compact ? 1.0 : 1.5;
                ctx.globalAlpha = MediaService.playing ? 0.55 : 0.25;
                ctx.stroke();

                ctx.restore();
            }
        }

        // The mask is captured through a ShaderEffectSource: an item hidden
        // with `visible: false` is never rendered, so it captures as pure
        // black -- which masked the whole record away. hideSource does the
        // hiding *after* the texture is taken.
        Rectangle {
            id: discMaskRect
            anchors.fill: parent
            radius: width / 2
            color: "white"
        }

        ShaderEffectSource {
            id: discMask
            sourceItem: discMaskRect
            hideSource: true
            visible: false
        }

        Item {
            id: discContent
            anchors.fill: parent

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: discMask
            }

            Rectangle { anchors.fill: parent; color: Theme.cardAlt }

            Image {
                id: art
                width: parent.width * 1.45
                height: width
                anchors.centerIn: parent
                source: MediaService.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                rotation: disc.spin
                visible: status === Image.Ready
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰝚"
            font.pixelSize: pane.compact ? 34 : 44
            color: Theme.textFaint
            visible: art.status !== Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Theme.border
            border.width: 1
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.13
            height: width
            radius: width / 2
            color: "#0a0a0f"
            border.color: "#33ffffff"
            border.width: 1
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            text: MediaService.hasPlayer ? MediaService.title : "Nothing playing"
            font.pixelSize: pane.compact ? 13 : 14
            font.bold: true
            color: Theme.textPrimary
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        Text {
            text: MediaService.hasPlayer ? MediaService.artist : "—"
            font.pixelSize: pane.compact ? 11 : 12
            color: Theme.textSecondary
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        Text {
            visible: MediaService.album !== ""
            text: MediaService.album
            font.pixelSize: pane.compact ? 9 : 10
            color: Theme.textMuted
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }

    // Seek bar. MPRIS exposes a writable position, so this is a real scrubber
    // wherever the player reports canSeek.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        visible: MediaService.hasPlayer && MediaService.length > 0

        Item {
            Layout.fillWidth: true
            implicitHeight: 14

            Rectangle {
                id: seekTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: seekMouse.containsMouse || seekMouse.pressed ? 6 : 4
                radius: height / 2
                color: Theme.cardAlt
                Behavior on height { NumberAnimation { duration: 120 } }

                Rectangle {
                    // While dragging, follow the pointer instead of the clock:
                    // the player only reports the new position after the seek
                    // lands, and the bar would otherwise snap backwards first.
                    width: (seekMouse.pressed ? seekMouse.fraction : MediaService.progress)
                           * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: MediaService.accent
                    Behavior on width {
                        enabled: !seekMouse.pressed
                        NumberAnimation { duration: 400 }
                    }
                }
            }

            Rectangle {
                id: seekHandle
                width: 10
                height: 10
                radius: 5
                color: MediaService.accent
                anchors.verticalCenter: parent.verticalCenter
                x: (seekMouse.pressed ? seekMouse.fraction : MediaService.progress)
                   * (parent.width - width)
                opacity: seekMouse.containsMouse || seekMouse.pressed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: seekMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: MediaService.canSeek
                cursorShape: MediaService.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                property real fraction: 0

                function update(x) {
                    fraction = Math.max(0, Math.min(1, x / width));
                }
                onPressed: mouse => update(mouse.x)
                onPositionChanged: mouse => { if (pressed) update(mouse.x); }
                onReleased: MediaService.seekFraction(fraction)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: MediaService.fmtTime(MediaService.position)
                font.pixelSize: 9
                color: Theme.textMuted
            }
            Item { Layout.fillWidth: true }
            Text {
                text: MediaService.fmtTime(MediaService.length)
                font.pixelSize: 9
                color: Theme.textMuted
            }
        }
    }

    Item { Layout.fillHeight: true; visible: pane.compact }

    // Transport
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: pane.compact ? 12 : 18

        Repeater {
            model: [
                { glyph: "󰒮", action: "prev", primary: false },
                { glyph: "", action: "toggle", primary: true },
                { glyph: "󰒭", action: "next", primary: false }
            ]
            delegate: Rectangle {
                readonly property bool primary: modelData.primary
                implicitWidth: primary ? (pane.compact ? 34 : 42) : (pane.compact ? 28 : 34)
                implicitHeight: implicitWidth
                radius: implicitWidth / 2
                color: primary ? MediaService.accent
                               : (btnMouse.containsMouse ? Theme.cardHover : Theme.cardAlt)
                border.color: primary ? "transparent" : Theme.border
                border.width: 1
                scale: btnMouse.pressed ? 0.92 : (btnMouse.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easeOutBack; easing.overshoot: 1.1 } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: modelData.primary
                          ? (MediaService.playing ? "󰏤" : "󰐊")
                          : modelData.glyph
                    font.pixelSize: parent.primary ? (pane.compact ? 16 : 20) : (pane.compact ? 13 : 16)
                    color: parent.primary ? "#0a0a0f" : Theme.textPrimary
                }

                MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "prev")
                            MediaService.previous();
                        else if (modelData.action === "next")
                            MediaService.next();
                        else
                            MediaService.playPause();
                    }
                }
            }
        }
    }
}
