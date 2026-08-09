import QtQuick
import QtQuick.Shapes

import qs.Commons

// Zkosený rám — základní stavební kámen celého HUD.
//
// Nesmí to být Rectangle: `radius` dělá kulaté rohy, tenhle vzhled chce
// 45° seříznutí. Obrys je jedna PathPolyline o osmi bodech, glow jsou tři
// stejné cesty pod ní s klesající alfou a rostoucí šířkou tahu — levnější
// a ostřejší než MultiEffect a nepotřebuje FBO.
Item {
    id: frame

    // Zkosení per roh. CP2077 nikdy neseřezává všechny čtyři stejně —
    // panel používá TL+BR, dlaždice TR+BL, takže vzniká „skládaný" dojem.
    property int cutTL: 0
    property int cutTR: Style.chamferSm
    property int cutBR: 0
    property int cutBL: Style.chamferSm

    property color fill:   Style.bgRaised
    property color stroke: Style.line
    property color glow:   Style.accentHot
    property real  glowStrength: 0.0      // 0 v klidu, ~0.35 aktivní, ~0.55 hover
    property int   strokeWidth: Style.hairline

    property bool ticks: false            // rohové HUD závorky
    property int  tickInset: 4
    property int  tickArm: 12

    Behavior on glowStrength { NumberAnimation { duration: Style.durFast; easing.type: Easing.OutQuad } }
    Behavior on stroke       { ColorAnimation  { duration: Style.durFast } }

    // Obrys proti směru hodinových ručiček od horního zkosení. Poslední bod
    // je zpátky na začátku — bez něj MiterJoin usekne cíp na posledním rohu.
    readonly property var outline: [
        Qt.point(cutTL,         0),
        Qt.point(width - cutTR, 0),
        Qt.point(width,         cutTR),
        Qt.point(width,         height - cutBR),
        Qt.point(width - cutBR, height),
        Qt.point(cutBL,         height),
        Qt.point(0,             height - cutBL),
        Qt.point(0,             cutTL),
        Qt.point(cutTL,         0)
    ]

    // Rohová závorka: L odsazené dovnitř. U seříznutého rohu se odsazení
    // odvíjí od velikosti řezu, aby závorka zůstala uvnitř diagonály.
    function tick(cut, ox, oy, sx, sy) {
        const o = Math.max(tickInset, cut * 0.7);
        return [
            Qt.point(ox + sx * o,              oy + sy * (o + tickArm)),
            Qt.point(ox + sx * o,              oy + sy * o),
            Qt.point(ox + sx * (o + tickArm),  oy + sy * o)
        ];
    }

    // --- glow: tři tahy pod výplní ---
    Repeater {
        model: [ { w: 7, a: 0.06 }, { w: 3, a: 0.16 }, { w: 1.5, a: 0.40 } ]

        Shape {
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: frame.glowStrength
            visible: opacity > 0.01

            ShapePath {
                fillColor: "transparent"
                strokeColor: Style.withAlpha(frame.glow, modelData.a)
                strokeWidth: modelData.w
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                PathPolyline { path: frame.outline }
            }
        }
    }

    // --- výplň + hairline ---
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: frame.fill
            strokeColor: frame.stroke
            strokeWidth: frame.strokeWidth
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: frame.outline }
        }
    }

    // --- rohové tiky ---
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: frame.ticks

        ShapePath {
            fillColor: "transparent"
            strokeColor: Style.withAlpha(Style.accentHot, 0.55)
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame.tick(frame.cutTL, 0, 0, 1, 1) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Style.withAlpha(Style.accentHot, 0.55)
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame.tick(frame.cutTR, frame.width, 0, -1, 1) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Style.withAlpha(Style.accentHot, 0.55)
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame.tick(frame.cutBR, frame.width, frame.height, -1, -1) }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: Style.withAlpha(Style.accentHot, 0.55)
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathPolyline { path: frame.tick(frame.cutBL, 0, frame.height, 1, -1) }
        }
    }
}
