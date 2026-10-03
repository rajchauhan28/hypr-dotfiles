import QtQuick
import QtQuick.Shapes

// The lit edge of a glass panel, for the "glass" theme.
//
// hyprglass frosts the background behind a layer, but it computes its own
// rim/bevel/refraction against the WHOLE layer surface with square corners --
// and our panels sit inside larger surfaces that touch the screen edges, so
// the plugin's rim landed on the screen edge as a hard white line. The plugin
// therefore only frosts (preset "shell_layer" in hypr/glass.lua) and every
// panel draws this rim itself, on its own rounded shape.
//
// Fill the parent with it (or size it to the panel body). It paints only a
// 1 px ring and a soft top sheen, never the fill, so it sits on top of the
// panel's own Theme.panelBg rectangle.
Item {
    id: rim

    property real radius: 16
    // Light from the top-left, a fainter bounce at the bottom-right, almost
    // nothing on the long edges -- the reference look.
    property real litAlpha: 0.55
    property real sideAlpha: 0.10
    property real bounceAlpha: 0.28
    property real sheenAlpha: 0.09
    property real sheenDepth: 0.38

    function white(a) {
        return Qt.rgba(1, 1, 1, a);
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: rim.width
                y2: rim.height
                GradientStop { position: 0.0; color: rim.white(rim.litAlpha) }
                GradientStop { position: 0.28; color: rim.white(rim.sideAlpha) }
                GradientStop { position: 0.72; color: rim.white(rim.sideAlpha) }
                GradientStop { position: 1.0; color: rim.white(rim.bounceAlpha) }
            }

            PathRectangle {
                x: 0
                y: 0
                width: rim.width
                height: rim.height
                radius: rim.radius
            }
            PathRectangle {
                x: 1
                y: 1
                width: Math.max(0, rim.width - 2)
                height: Math.max(0, rim.height - 2)
                radius: Math.max(0, rim.radius - 1)
            }
        }
    }

    // Inner sheen: the top of the glass catches a little more light.
    Rectangle {
        x: 1
        y: 1
        width: Math.max(0, rim.width - 2)
        height: Math.max(0, (rim.height - 2) * rim.sheenDepth)
        topLeftRadius: Math.max(0, rim.radius - 1)
        topRightRadius: Math.max(0, rim.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: rim.white(rim.sheenAlpha) }
            GradientStop { position: 1.0; color: rim.white(0) }
        }
    }
}
