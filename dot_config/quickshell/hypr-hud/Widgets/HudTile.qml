import QtQuick

import qs.Commons

// Dlaždice: zkosený rám + hlavička „[01]  A U D I O  ─────" + obsah.
//
// Výška se počítá z obsahu (Column.implicitHeight), takže sekce nemusí nic
// hlídat — ale jednotlivé sekce si drží konstantní výšku samy, ať panel
// neposkakuje při změně stavu.
Item {
    id: tile

    property string index: "01"
    property string label: ""
    property color  accent: Style.accentHot
    property bool   attention: false     // výstražný pruh na levé hraně
    property bool   hovered: false

    default property alias content: contentColumn.data

    readonly property int pad: Style.spacingM
    readonly property int headerHeight: 16

    implicitHeight: pad * 2 + headerHeight + Style.spacingS + contentColumn.implicitHeight

    // Glitch puls při změně stavu (přepnutí sinku, mute, DND) — ne při každém
    // otevření panelu. Rozsvícení rámu plus krátký blikot; žádný shader,
    // qsb v runtime closure nixového quickshellu není.
    property real flashBoost: 0

    function flash() {
        flashAnim.restart();
    }

    ParallelAnimation {
        id: flashAnim

        SequentialAnimation {
            NumberAnimation { target: tile; property: "flashBoost"; to: 1.0; duration: 0 }
            NumberAnimation {
                target: tile; property: "flashBoost"; to: 0.0
                duration: Style.durGlitch * 3; easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            NumberAnimation { target: tile; property: "opacity"; to: 0.72; duration: 18 }
            NumberAnimation { target: tile; property: "opacity"; to: 1.00; duration: 18 }
            NumberAnimation { target: tile; property: "opacity"; to: 0.90; duration: 18 }
            NumberAnimation { target: tile; property: "opacity"; to: 1.00; duration: 18 }
        }
    }

    HudFrame {
        id: frame
        anchors.fill: parent
        cutTR: Style.chamferSm
        cutBL: Style.chamferSm
        cutTL: 0
        cutBR: 0
        fill: Style.bgRaised
        stroke: tile.attention ? Style.danger
                               : (tile.hovered ? tile.accent : Style.line)
        glow: tile.accent
        glowStrength: Math.min(1.0, (tile.hovered ? 0.55 : (tile.attention ? 0.35 : 0.0))
                                    + tile.flashBoost * 0.6)
    }

    // Výstražný šraf na levé hraně. Odsazený od zkosených rohů, aby nekoukal ven.
    CautionStripe {
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Style.chamferSm
        anchors.bottomMargin: Style.chamferSm
        width: 8
        color: Style.danger
        visible: tile.attention
    }

    Item {
        anchors.fill: parent
        anchors.margins: tile.pad

        // --- hlavička ---
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: tile.headerHeight

            HudFrame {
                id: indexChip
                width: indexText.implicitWidth + 8
                height: parent.height
                cutTR: 3
                cutBL: 3
                cutTL: 0
                cutBR: 0
                fill: Style.withAlpha(Style.warn, 0.12)
                stroke: Style.withAlpha(Style.warn, 0.45)

                Text {
                    id: indexText
                    anchors.centerIn: parent
                    text: tile.index
                    color: Style.warn
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontMicro
                    font.bold: true
                }
            }

            Text {
                id: labelText
                anchors.left: indexChip.right
                anchors.leftMargin: Style.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: tile.label.toUpperCase()
                color: Style.textDim
                font.family: Style.fontFamily
                font.pixelSize: Style.fontLabel
                font.letterSpacing: Style.labelSpacing
            }

            // Hairline pravítko do zbytku řádku — klasika HUD.
            Rectangle {
                anchors.left: labelText.right
                anchors.leftMargin: Style.spacingS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Style.line
                border.width: 0
            }
        }

        // --- obsah ---
        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: Style.spacingS
            spacing: Style.spacingS
        }
    }
}
