import QtQuick

import qs.Commons

// Slider s hranatým knoflíkem. Ovládání záměrně kopíruje waybar: tažení,
// klik kamkoli do stopy a scroll po 5 %.
Item {
    id: slider

    property real value: 0.0        // 0..1
    property real step: 0.05
    property color accent: Style.accent
    property bool muted: false

    // Nese `moved`, ne obousměrný binding — hodnota patří PipeWiru, ne UI.
    signal moved(real value)

    implicitHeight: 22
    readonly property int trackHeight: 6
    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: slider.trackHeight
        color: Style.bgSunken
        border.width: 0

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * slider.clamped
            color: slider.muted ? Style.withAlpha(Style.danger, 0.55) : slider.accent
            border.width: 0

            Behavior on color { ColorAnimation { duration: Style.durFast } }
        }
    }

    // Knoflík: malý zkosený blok, ne kolečko.
    HudFrame {
        id: knob
        width: 12
        height: 22
        cutTR: Style.chamferXs
        cutBL: Style.chamferXs
        cutTL: 0
        cutBR: 0
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((slider.width - width) * slider.clamped)
        fill: slider.muted ? Style.danger : Style.accentHot
        stroke: Style.bg
        glow: slider.muted ? Style.danger : Style.accentHot
        glowStrength: mouse.containsMouse || mouse.pressed ? 0.6 : 0.25
    }

    function valueAt(px) {
        return Math.max(0, Math.min(1, px / slider.width));
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: (e) => slider.moved(slider.valueAt(e.x))
        onPositionChanged: (e) => { if (pressed) slider.moved(slider.valueAt(e.x)); }
    }

    WheelHandler {
        target: slider
        onWheel: (e) => {
            const dir = e.angleDelta.y > 0 ? 1 : -1;
            slider.moved(Math.max(0, Math.min(1, slider.clamped + dir * slider.step)));
        }
    }
}
