import QtQuick
import QtQuick.Effects

// A lock-screen card: the ss / mm watch windows, the password pill and the
// switch-user button.
//
// Dark and light paint `fill` with a 1px `rim`, exactly as the plain
// Rectangles these replaced did.
//
// Glass is real glass. The session lock is not a layer surface, so the
// compositor's glass plugin never sees it, but the lock paints its own
// wallpaper (`backdrop`) in this same scene: the card shows a live, heavily
// blurred copy of the backdrop behind itself, tinted Theme.panelBg, with a
// soft top sheen. The rim (Theme.panelBorder) stays this Rectangle's own
// border so it sits on top. Outside glass mode the Loader is inactive and
// none of it exists, so dark and light pay nothing for it.
Rectangle {
    id: card

    property Item backdrop: null
    property color fill: "transparent"
    property color rim: "transparent"
    property bool alert: false      // danger rim, e.g. a failed unlock
    property bool hovered: false    // glass only: lifts the tint

    color: Theme.glass ? "transparent" : fill
    border.width: 1
    border.color: alert ? Theme.danger : (Theme.glass ? Theme.panelBorder : rim)

    Loader {
        // z < 0 paints beneath the Rectangle itself, so the rim and the
        // card's own children stay above the frosting.
        z: -1
        anchors.fill: parent
        active: Theme.glass && card.backdrop !== null && card.visible
        sourceComponent: frostComponent
    }

    Component {
        id: frostComponent

        Item {
            id: frost

            // Capture a margin around the card so the blur samples real
            // wallpaper at the edges instead of fading into transparency.
            readonly property real pad: 48
            readonly property rect area: {
                // Touch the geometry so the crop follows the card live.
                void (card.x + card.y + card.width + card.height
                      + card.backdrop.width + card.backdrop.height);
                var p = card.mapToItem(card.backdrop, 0, 0);
                return Qt.rect(p.x - pad, p.y - pad,
                               card.width + 2 * pad, card.height + 2 * pad);
            }

            ShaderEffectSource {
                id: snapshot
                sourceItem: card.backdrop
                sourceRect: frost.area
                live: true          // follows video wallpapers frame by frame
                visible: false
                // Half resolution: it is about to be blurred anyway.
                textureSize: Qt.size(Math.max(1, Math.ceil(frost.area.width / 2)),
                                     Math.max(1, Math.ceil(frost.area.height / 2)))
            }

            // The card's rounded shape, in the effect's (padded) coordinates.
            Item {
                id: shape
                x: -frost.pad
                y: -frost.pad
                width: card.width + 2 * frost.pad
                height: card.height + 2 * frost.pad
                visible: false
                layer.enabled: true

                Rectangle {
                    x: frost.pad
                    y: frost.pad
                    width: card.width
                    height: card.height
                    radius: card.radius
                    antialiasing: true
                }
            }

            MultiEffect {
                x: -frost.pad
                y: -frost.pad
                width: card.width + 2 * frost.pad
                height: card.height + 2 * frost.pad
                source: snapshot
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                saturation: 0.2
                maskEnabled: true
                maskSource: shape
            }

            Rectangle {
                anchors.fill: parent
                radius: card.radius
                color: card.hovered ? Qt.tint(Theme.panelBg, Theme.ink(0.08)) : Theme.panelBg
            }

            Rectangle {
                anchors.fill: parent
                radius: card.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.ink(0.18) }
                    GradientStop { position: 0.4; color: Theme.ink(0) }
                }
            }
        }
    }
}
