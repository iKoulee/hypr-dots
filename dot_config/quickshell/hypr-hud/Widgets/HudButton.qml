import QtQuick

import qs.Commons

// Zkosené tlačítko. Používá se pro transport přehrávače, čipy audio zařízení
// i přepínač DND — liší se jen obsahem a barvou akcentu.
Item {
    id: btn

    property string icon: ""             // glyph z Nerd Fontu
    property string label: ""
    property color  accent: Style.accentHot
    property bool   active: false        // vybraný / zapnutý stav
    property int    hPadding: Style.spacingM

    signal clicked()

    readonly property bool hovered: mouse.containsMouse && btn.enabled

    implicitWidth: Math.max(40, row.implicitWidth + hPadding * 2)
    implicitHeight: 30
    opacity: btn.enabled ? 1.0 : 0.35

    Behavior on opacity { NumberAnimation { duration: Style.durFast } }

    HudFrame {
        anchors.fill: parent
        cutTR: Style.chamferXs
        cutBL: Style.chamferXs
        cutTL: 0
        cutBR: 0
        fill: btn.active ? Style.withAlpha(btn.accent, 0.16)
                         : (btn.hovered ? Style.surfaceHi : Style.bgSunken)
        stroke: btn.active ? btn.accent : (btn.hovered ? btn.accent : Style.line)
        glow: btn.accent
        glowStrength: btn.hovered ? 0.55 : (btn.active ? 0.35 : 0.0)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Style.spacingXs

        Text {
            visible: btn.icon.length > 0
            text: btn.icon
            color: btn.active ? btn.accent : (btn.enabled ? Style.text : Style.textDim)
            font.family: Style.fontFamily
            font.pixelSize: Style.fontTitle
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: btn.label.length > 0
            text: btn.label
            color: btn.active ? btn.accent : (btn.enabled ? Style.textMuted : Style.textDim)
            font.family: Style.fontFamily
            font.pixelSize: Style.fontLabel
            font.letterSpacing: 1.5
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (btn.enabled) btn.clicked()
    }
}
