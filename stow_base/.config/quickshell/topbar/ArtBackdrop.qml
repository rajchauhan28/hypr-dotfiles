import QtQuick
import QtQuick.Effects

// Heavily blurred album art behind a dark scrim, so the player card takes on
// the colour of whatever is playing without hurting text contrast.
// Meant to fill a Card that has `clip: true`.
Item {
    id: backdrop

    property string source: MediaService.artPath !== "" ? "file://" + MediaService.artPath
                                                        : MediaService.artUrl
    property real intensity: 0.42

    Image {
        id: src
        anchors.fill: parent
        source: backdrop.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // Downscaled hard: it is about to be blurred into a wash, so decoding
        // a 1000px cover at full size would be wasted work every track change.
        sourceSize.width: 160
        sourceSize.height: 160
        visible: false
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: src
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.35
        opacity: src.status === Image.Ready ? backdrop.intensity : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }

        // Slow drift, so a paused track still feels alive rather than static.
        scale: 1.15
        SequentialAnimation on x {
            running: src.status === Image.Ready
            loops: Animation.Infinite
            NumberAnimation { from: -14; to: 14; duration: 24000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 14; to: -14; duration: 24000; easing.type: Easing.InOutSine }
        }
    }

    // Scrim: without it the blur washes out the small grey secondary text.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#99101014" }
            GradientStop { position: 1.0; color: "#e6101014" }
        }
    }
}
