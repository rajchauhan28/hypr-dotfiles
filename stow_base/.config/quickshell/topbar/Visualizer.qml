import QtQuick

// Spectrum visualizer: supports both horizontal mirrored bars and a vertical
// glassmorphic pill spectrum with gravity peak caps.
Item {
    id: viz

    property color tint: MediaService.glow ? MediaService.glow : MediaService.accent
    property bool vertical: false
    property var peaks: []

    implicitWidth: vertical ? 50 : 200
    implicitHeight: vertical ? 140 : 40

    readonly property int count: MediaService.bands.length

    onCountChanged: if (viz.peaks.length !== viz.count) viz.peaks = new Array(viz.count).fill(0)

    Connections {
        target: MediaService
        function onBandsChanged() {
            var b = MediaService.bands;
            if (b.length === 0)
                return;
            var p = viz.peaks;
            if (p.length !== b.length)
                p = new Array(b.length).fill(0);
            for (var i = 0; i < b.length; i++)
                p[i] = b[i] > p[i] ? b[i] : Math.max(0, p[i] - 1.8);
            viz.peaks = p;
            bars.requestPaint();
        }
    }

    // Glassmorphic background container when vertical
    Rectangle {
        anchors.fill: parent
        visible: viz.vertical
        color: "#0dffffff"
        border.color: "#18ffffff"
        border.width: 1
        radius: 12
    }

    Canvas {
        id: bars
        anchors.fill: parent
        anchors.margins: viz.vertical ? 6 : 0
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var b = MediaService.bands;
            var n = b.length;
            if (n === 0)
                return;

            if (viz.vertical) {
                // Vertical Glassmorphic Pill Spectrum (bottom to top)
                var slotV = width / n;
                var bwV = Math.max(2, slotV * 0.65);
                var maxHV = height - 8;

                for (var v = 0; v < n; v++) {
                    var xV = v * slotV + (slotV - bwV) / 2;
                    var hV = Math.max(2, (b[v] / 100) * maxHV);
                    var yV = height - hV - 2;

                    var gV = ctx.createLinearGradient(0, height, 0, yV);
                    gV.addColorStop(0.0, Qt.rgba(viz.tint.r, viz.tint.g, viz.tint.b, 0.2));
                    gV.addColorStop(0.7, viz.tint);
                    gV.addColorStop(1.0, "#ffffff");
                    ctx.fillStyle = gV;

                    var rV = Math.min(bwV / 2, hV / 2);
                    ctx.beginPath();
                    ctx.roundedRect(xV, yV, bwV, hV, rV, rV);
                    ctx.fill();

                    var pkV = viz.peaks[v] || 0;
                    if (pkV > 4) {
                        var pyV = Math.max((pkV / 100) * maxHV, hV + 3);
                        ctx.fillStyle = "#ffffff";
                        ctx.globalAlpha = 0.85;
                        ctx.beginPath();
                        ctx.roundedRect(xV, height - pyV - 3, bwV, 2, bwV / 2, bwV / 2);
                        ctx.fill();
                        ctx.globalAlpha = 1.0;
                    }
                }
            } else {
                // Horizontal Mirrored Spectrum (center out)
                var mid = height / 2;
                var slot = width / n;
                var bw = Math.max(2, slot * 0.62);
                var maxH = mid - 3;

                for (var i = 0; i < n; i++) {
                    var x = i * slot + (slot - bw) / 2;
                    var h = Math.max(1.5, (b[i] / 100) * maxH);

                    var g = ctx.createLinearGradient(0, mid - h, 0, mid + h);
                    g.addColorStop(0.0, Qt.rgba(viz.tint.r, viz.tint.g, viz.tint.b, 0.25));
                    g.addColorStop(0.5, viz.tint);
                    g.addColorStop(1.0, Qt.rgba(viz.tint.r, viz.tint.g, viz.tint.b, 0.25));
                    ctx.fillStyle = g;

                    var r = Math.min(bw / 2, h);
                    ctx.beginPath();
                    ctx.roundedRect(x, mid - h, bw, h * 2, r, r);
                    ctx.fill();

                    var pk = viz.peaks[i] || 0;
                    if (pk > 4) {
                        var py = Math.max((pk / 100) * maxH, h + 2);
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.55);
                        ctx.beginPath();
                        ctx.roundedRect(x, mid - py - 1.5, bw, 1.5, 1, 1);
                        ctx.roundedRect(x, mid + py, bw, 1.5, 1, 1);
                        ctx.fill();
                    }
                }
            }
        }
    }

    // Idle state line
    Rectangle {
        anchors.centerIn: parent
        width: viz.vertical ? parent.width - 12 : parent.width
        height: 1
        color: Theme.border
        opacity: viz.count === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
}
