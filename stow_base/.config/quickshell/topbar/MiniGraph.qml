import QtQuick

Rectangle {
    id: chart

    // Each entry in series is an array of numbers, newest sample last.
    property var series: []
    property var lineColors: [Theme.accent]
    property real minimum: 0
    property real maximum: 100
    property bool autoMaximum: false
    property bool fillFirst: true
    property bool smooth: true
    property string emptyText: "collecting…"

    radius: Theme.radiusSmall
    color: Theme.cardAlt
    border.color: Theme.border
    border.width: 1
    clip: true

    function repaint() { canvas.requestPaint(); }
    onSeriesChanged: repaint()
    onWidthChanged: repaint()
    onHeightChanged: repaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var all = chart.series || [];
            if (all.length === 0)
                return;

            var upper = chart.maximum;
            if (chart.autoMaximum) {
                upper = 1;
                for (var s = 0; s < all.length; ++s)
                    for (var k = 0; k < all[s].length; ++k)
                        upper = Math.max(upper, Number(all[s][k]) || 0);
                // Keep low traffic/temperature changes readable without making
                // the scale jump on every tiny sample.
                upper = Math.ceil(upper / 10) * 10;
            }
            var span = Math.max(1, upper - chart.minimum);
            function py(v) {
                var value = Math.max(chart.minimum, Math.min(upper, Number(v) || 0));
                return height - 3 - ((value - chart.minimum) / span) * (height - 6);
            }

            function trace(values, step, moveToStart) {
                if (moveToStart)
                    ctx.moveTo(0, py(values[0]));
                if (!chart.smooth || values.length < 3) {
                    for (var l = 1; l < values.length; ++l)
                        ctx.lineTo(l * step, py(values[l]));
                    return;
                }

                // Catmull–Rom points converted to cubic Bézier controls. The
                // curve still passes through every real sample, but avoids the
                // sharp corners of a straight line graph.
                for (var p = 0; p < values.length - 1; ++p) {
                    var p0 = py(values[Math.max(0, p - 1)]);
                    var p1 = py(values[p]);
                    var p2 = py(values[p + 1]);
                    var p3 = py(values[Math.min(values.length - 1, p + 2)]);
                    ctx.bezierCurveTo(
                        p * step + step / 6, p1 + (p2 - p0) / 6,
                        (p + 1) * step - step / 6, p2 - (p3 - p1) / 6,
                        (p + 1) * step, p2);
                }
            }

            for (var i = 0; i < all.length; ++i) {
                var values = all[i] || [];
                if (values.length < 2)
                    continue;
                var step = width / Math.max(1, values.length - 1);
                var color = chart.lineColors[i % chart.lineColors.length];

                if (i === 0 && chart.fillFirst) {
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    ctx.lineTo(0, py(values[0]));
                    trace(values, step, false);
                    ctx.lineTo((values.length - 1) * step, height);
                    ctx.closePath();
                    ctx.globalAlpha = 0.10;
                    ctx.fillStyle = color;
                    ctx.fill();
                    ctx.globalAlpha = 1.0;
                }

                ctx.beginPath();
                trace(values, step, true);
                ctx.lineWidth = i === 0 ? 1.7 : 1.25;
                ctx.strokeStyle = color;
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !chart.series || chart.series.length === 0
                 || !chart.series[0] || chart.series[0].length < 2
        text: chart.emptyText
        font.pixelSize: 9
        color: Theme.textFaint
    }
}
