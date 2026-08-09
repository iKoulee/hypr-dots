import QtQuick

import qs.Commons

// Text s RGB třepením — chromatická aberace bez jediného shaderu.
//
// Vlastní shadery tu nejdou: `qsb` (qt6.qtshadertools) není v runtime closure
// nixového quickshellu a Qt5Compat.GraphicalEffects taky ne. Tři Texty přes
// sebe udělají totéž a stojí nic.
//
// Nasazovat jen na velký text (hodiny, název skladby). Na popisky pod ~13 px
// se to rozmaže k nečitelnosti.
Item {
    id: root

    property string text: ""
    property color  color: Style.text
    property alias  font: base.font

    property real baseFringe: 1.5      // klidový rozestup kanálů v px
    property real fringe: baseFringe

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    // Jednorázový glitch puls. Volá se při změně stavu (přepnutí sinku, mute,
    // DND), ne při každém otevření panelu — po padesátém otevření by to otravovalo.
    function pulse() {
        pulseAnim.restart();
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "fringe"; to: 4.0; duration: 0 }
        NumberAnimation {
            target: root; property: "fringe"; to: root.baseFringe
            duration: Style.durGlitch; easing.type: Easing.OutCubic
        }
    }

    Text {
        text: root.text
        font: base.font
        color: Style.danger
        opacity: 0.35
        x: -root.fringe
    }

    Text {
        text: root.text
        font: base.font
        color: Style.accentHot
        opacity: 0.35
        x: root.fringe
    }

    Text {
        id: base
        text: root.text
        color: root.color
        font.family: Style.fontFamily
        font.pixelSize: Style.fontTitle
    }
}
