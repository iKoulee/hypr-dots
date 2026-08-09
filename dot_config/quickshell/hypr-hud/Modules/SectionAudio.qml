import QtQuick

import qs.Commons
import qs.Services
import qs.Widgets

HudTile {
    id: section

    index: "01"
    label: "Audio"
    accent: Style.accentHot
    attention: Audio.muted

    readonly property var desc: Audio.describe(Audio.sink)

    // --- řádek zařízení: ikona (mute), přezdívka, procenta ---
    Item {
        width: parent.width
        height: 26

        HudButton {
            id: muteBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 26
            hPadding: Style.spacingS
            accent: Style.danger
            active: Audio.muted
            enabled: Audio.ready
            icon: Audio.muted ? Style.iconVolMute
                              : (Audio.volume < 0.5 ? Style.iconVolLow : Style.iconVolHigh)
            onClicked: {
                Audio.toggleMute();
                section.flash();
            }
        }

        Text {
            anchors.left: muteBtn.right
            anchors.leftMargin: Style.spacingM
            anchors.right: pct.left
            anchors.rightMargin: Style.spacingS
            anchors.verticalCenter: parent.verticalCenter
            // Ikona z devices.conf může chybět (literální glyf se dá ztratit),
            // proto fallback na vlastní.
            text: (section.desc.icon.length > 0 ? section.desc.icon
                                                : Style.iconSpeaker) + "  " + section.desc.label
            color: Audio.muted ? Style.textDim : Style.text
            font.family: Style.fontFamily
            font.pixelSize: Style.fontTitle
            elide: Text.ElideRight
        }

        Text {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Audio.ready ? Math.round(Audio.volume * 100) + " %" : "—"
            color: Audio.muted ? Style.danger : Style.accentHot
            font.family: Style.fontFamily
            font.pixelSize: Style.fontTitle
            font.bold: true
        }
    }

    // --- hlasitost ---
    HudSlider {
        width: parent.width
        value: Audio.volume
        muted: Audio.muted
        enabled: Audio.ready
        onMoved: (v) => Audio.setVolume(v)
    }

    // --- čipy zařízení ---
    // Flow, ne Row: přezdívky jsou libovolně dlouhé a tři zařízení se do
    // 524 px nemusí vejít na jeden řádek.
    Flow {
        width: parent.width
        spacing: Style.spacingS

        Repeater {
            model: Audio.sinks

            HudButton {
                required property var modelData

                readonly property var d: Audio.describe(modelData)

                height: 30
                hPadding: Style.spacingS
                icon: d.icon.length > 0 ? d.icon : Style.iconSpeaker
                label: d.label
                active: Audio.isDefault(modelData)
                accent: Style.accentHot
                onClicked: {
                    Audio.setSink(modelData);
                    section.flash();
                }
            }
        }
    }
}
