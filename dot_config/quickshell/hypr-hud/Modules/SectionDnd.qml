import QtQuick

import qs.Commons
import qs.Services
import qs.Widgets

HudTile {
    id: section

    index: "03"
    label: "Do not disturb"
    accent: Style.danger
    attention: Dnd.active

    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // Parita s tooltipem skriptu: kritické notifikace projdou i v DND
            // (mako criteria [mode=do-not-disturb urgency=critical]).
            text: Dnd.active ? "CRITICAL STILL PASSES" : "NOTIFICATIONS ON"
            color: Dnd.active ? Style.danger : Style.textDim
            font.family: Style.fontFamily
            font.pixelSize: Style.fontLabel
            font.letterSpacing: Style.labelSpacing
        }

        HudButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 74
            height: 26
            hPadding: Style.spacingS
            accent: Style.danger
            active: Dnd.active
            icon: Dnd.active ? Style.iconBellOff : Style.iconBell
            label: Dnd.active ? "ON" : "OFF"
            onClicked: {
                Dnd.toggle();
                section.flash();
            }
        }
    }
}
