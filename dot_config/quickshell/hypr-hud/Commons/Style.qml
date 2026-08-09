pragma Singleton

// QtQuick je tu kvůli základnímu typu `color` a funkcím Qt.rgba/Qt.color —
// se samotným `import Quickshell` skončí načtení na "color is not a type".
import QtQuick
import Quickshell

// Tokeny control centeru. Tohle je token soubor pro HUD a nic víc — repo nemá
// centrální paletu (viz CLAUDE.md, Color scheme) a waybar s wofi zůstávají na
// Catppuccinu. HUD jede na Tokyo Night, aby ladil s mako a satty.
Singleton {
    id: root

    // ---- Barvy: Tokyo Night --------------------------------------------
    readonly property color bg:        "#1a1b26"  // základ panelu, shodný s mako
    readonly property color bgSunken:  "#16161e"  // stopa slideru, placeholder obalu
    readonly property color bgRaised:  "#1f2335"  // výplň dlaždice
    readonly property color surfaceHi: "#292e42"  // hover výplň, oddělovače
    readonly property color line:      "#3b4261"  // hairline rám v klidu
    readonly property color textDim:   "#565f89"  // popisky sekcí, disabled
    readonly property color textMuted: "#a9b1d6"  // interpret, datum
    readonly property color text:      "#c0caf5"  // primární text
    readonly property color accent:    "#7aa2f7"  // výplň slideru, fokus
    readonly property color accentHot: "#7dcfff"  // HUD azur: glow, rohové tiky
    readonly property color warn:      "#e0af68"  // výstražné šrafy, indexy sekcí
    readonly property color danger:    "#f7768e"  // mute, DND, červený kanál třepení
    readonly property color ok:        "#9ece6a"  // přehrává se
    readonly property color media:     "#bb9af7"  // akcent sekce MEDIA

    // Signaturní žlutá Cyberpunku 2077 (#fcee0a) se tu záměrně nepoužívá —
    // v Tokyo Night nemá protějšek a vedle mako notifikace by řvala. Její roli
    // si dělí `warn` (ornamentální: šrafy, indexy) a `accentHot` (interaktivní:
    // glow, tiky). Azur je v CP2077 druhý signaturní tón, takže jazyk zůstává.

    readonly property real panelAlpha: 0.88   // blur si bere hl.layer_rule v hyprland.lua

    // Qt.alpha() je novinka, Qt.rgba() umí každá verze — a `c` může přijít
    // i jako string, proto průchod přes Qt.color().
    function withAlpha(c, a) {
        const k = Qt.color(c);
        return Qt.rgba(k.r, k.g, k.b, a);
    }

    // ---- Geometrie ------------------------------------------------------
    readonly property int chamfer:   14   // zkosení rohů panelu
    readonly property int chamferSm:  8   // zkosení dlaždic
    readonly property int chamferXs:  4   // zkosení tlačítek, čipů, knoflíku
    readonly property int hairline:   1

    readonly property int spacingXs:  4
    readonly property int spacingS:   8
    readonly property int spacingM:  12
    readonly property int spacingL:  18

    readonly property int panelWidth: 560
    // Posun od středu obrazovky. Mako notifikace sedí top-center na x 2342–2778;
    // panel je na overlay vrstvě, takže centrovaný by je úplně překryl. +800
    // ho posadí pod pravý cluster waybaru, který stejně duplikuje. Vlevo = -800.
    readonly property int hudOffsetX: 800

    // ---- Typografie -----------------------------------------------------
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontDisplay: 44  // hodiny
    readonly property int fontTitle:   15  // název skladby, přezdívka zařízení
    readonly property int fontBody:    13  // datum, interpret
    readonly property int fontLabel:   10  // "[01] A U D I O", uppercase
    readonly property int fontMicro:    9  // časy, indexy
    readonly property real labelSpacing: 2.5

    // ---- Ikony ----------------------------------------------------------
    // Zapsané jako \u escapy schválně. Glyfy z private use area se při editaci
    // nástrojem, který je nepřenese, tiše promění v prázdný řetězec — v tomhle
    // repu se to už jednou stalo (hypr-dnd, devices.conf, waybar format-muted;
    // viz CLAUDE.md, sekce Audio). Escapy tenhle problém nemají a jdou grepnout.
    // Ověřeno proti JetBrainsMonoNerdFont-Regular.ttf, že písmo všechny má.
    readonly property string iconVolHigh: "\uF028"   // fa-volume-up
    readonly property string iconVolLow:  "\uF027"   // fa-volume-down
    readonly property string iconVolMute: "\uF026"   // fa-volume-off
    readonly property string iconPrev:    "\uF048"   // fa-step-backward
    readonly property string iconPlay:    "\uF04B"   // fa-play
    readonly property string iconPause:   "\uF04C"   // fa-pause
    readonly property string iconNext:    "\uF051"   // fa-step-forward
    readonly property string iconMusic:   "\uF001"   // fa-music
    readonly property string iconBell:    "\uF0F3"   // fa-bell
    readonly property string iconBellOff: "\uF1F6"   // fa-bell-slash
    readonly property string iconSpeaker: "\uF025"   // fa-headphones (fallback zařízení)

    // ---- Doby animací ---------------------------------------------------
    readonly property int durFast:   120
    readonly property int durBase:   200
    readonly property int durGlitch:  90

    // ---- Pravidlo pro celý config ---------------------------------------
    // QTBUG-137166: Rectangle s color: "transparent", u kterého se sáhne na
    // `border`, zneviditelní všechno pod sebou. Rámečky proto kreslí Shape,
    // ne Rectangle; kde je Rectangle nutný (stopa slideru, pravítka), má buď
    // neprůhlednou barvu, nebo "#00000000" A explicitní border.width: 0.
}
