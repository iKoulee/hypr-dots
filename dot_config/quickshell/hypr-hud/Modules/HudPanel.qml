import QtQuick

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.Commons
import qs.Services
import qs.Widgets

// Okno control centeru. Layer-shell overlay, otevírá se přes IPC (viz shell.qml),
// zavírá klikem mimo, Escapem nebo dalším stiskem Super+C.
PanelWindow {
    id: hud

    visible: false
    color: "transparent"

    // Namespace se po připojení okna už nedá změnit — proto deklarativně.
    // Na tohle jméno míří `hl.layer_rule` v hyprland.lua (blur).
    WlrLayershell.namespace: "hypr-hud"
    WlrLayershell.layer: WlrLayer.Overlay
    // Bez exkluzivní klávesnice by Escape nedorazil. Když je panel zavřený,
    // fokus se vrací kompozitoru — jinak by si držel klávesnici celou session.
    WlrLayershell.keyboardFocus: hud.visible ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None

    // Normal + exclusiveZone 0 znamená „nic si nerezervuj, ale respektuj cizí
    // exkluzivní zóny" → panel se odsune pod waybar sám. Tím nevzniká čtvrté
    // místo, kde je natvrdo napsaná jeho výška (viz mako outer-margin).
    anchors.top: true
    anchors.left: true
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Normal

    margins.top: Style.spacingS
    // Mako notifikace sedí top-center; panel na overlay vrstvě by je centrovaný
    // překryl, proto posun. Detail a naměřené souřadnice v Style.hudOffsetX.
    margins.left: hud.screen
        ? Math.round(hud.screen.width / 2 - hud.implicitWidth / 2) + Style.hudOffsetX
        : Style.hudOffsetX

    implicitWidth: Style.panelWidth
    implicitHeight: column.implicitHeight + Style.spacingL * 2 + stripe.height

    readonly property int stripeHeight: 6

    // Klik mimo panel ho zavře. Pod Hyprlandem je tohle doporučená cesta
    // (hyprland_focus_grab_v1), ne PopupWindow.grabFocus.
    //
    // `active` se NESMÍ nabindovat na hud.visible, i když to tak vypadá
    // přirozeně. Dokumentace říká, že se na true přepne až ve chvíli, kdy grab
    // opravdu začne, což vyžaduje aspoň jedno *viditelné* okno — v okamžiku,
    // kdy hud.visible přeskočí na true, ale surface ještě není namapovaný,
    // takže grab nezačne. A protože se hud.visible pak už nemění, binding se
    // nikdy nepřevyhodnotí a klik mimo panel nezavře. Navíc do `active` píše
    // i kompozitor (při zavření grabu), což by binding stejně rozbilo.
    // Proto imperativně, až po namapování okna.
    HyprlandFocusGrab {
        id: focusGrab
        windows: [hud]
        onCleared: hud.visible = false
    }

    // Jedno projití smyčkou událostí nestačí, surface se commituje až po
    // vykreslení prvního snímku — proto krátký časovač, ne Qt.callLater.
    Timer {
        id: grabDelay
        interval: 50
        repeat: false
        onTriggered: if (hud.visible) focusGrab.active = true
    }

    onVisibleChanged: {
        if (visible) {
            scanAnim.restart();
            grabDelay.restart();
        } else {
            focusGrab.active = false;
        }
        // Stav DND se dá jen číst (mako o změně režimu nic nevysílá), takže
        // se pollinguje — ale jen dokud je panel otevřený.
        Dnd.polling = visible;
    }

    HudFrame {
        anchors.fill: parent
        cutTL: Style.chamfer
        cutBR: Style.chamfer
        cutTR: 0
        cutBL: 0
        fill: Style.withAlpha(Style.bg, Style.panelAlpha)
        stroke: Style.withAlpha(Style.accentHot, 0.45)
        glow: Style.accentHot
        glowStrength: 0.3
        ticks: true
    }

    // Výstražný pás pod horní hranou. Odsazený od zkoseného levého rohu.
    CautionStripe {
        id: stripe
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.chamfer
        anchors.rightMargin: 1
        height: hud.stripeHeight
        thickness: 5
        pitch: 13
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: stripe.bottom
        anchors.leftMargin: Style.spacingL
        anchors.rightMargin: Style.spacingL
        anchors.topMargin: Style.spacingL - stripe.height
        spacing: Style.spacingM

        SectionClock {
            width: parent.width
            open: hud.visible
        }

        SectionAudio {
            width: parent.width
        }

        SectionMedia {
            width: parent.width
            open: hud.visible
        }

        SectionDnd {
            width: parent.width
        }
    }

    // „Boot" sken při otevření — jedna linka shora dolů. Nejlevnější efekt,
    // jaký existuje, a sedí na scan overlay z CP2077.
    Rectangle {
        id: scanLine
        width: parent.width
        height: 1
        color: Style.accentHot
        opacity: 0
        border.width: 0
        y: 0
    }

    ParallelAnimation {
        id: scanAnim
        NumberAnimation {
            target: scanLine; property: "y"; from: 0; to: hud.implicitHeight
            duration: 240; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: scanLine; property: "opacity"; from: 0.8; to: 0.0
            duration: 240
        }
    }

    // Escape musí chytit item s fokusem uvnitř okna.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: hud.visible = false
    }
}
