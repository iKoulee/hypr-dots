import QtQuick

import Quickshell
import Quickshell.Services.Mpris

import qs.Commons
import qs.Widgets

HudTile {
    id: section

    index: "02"
    label: "Media"
    accent: Style.media
    attention: player === null

    property bool open: false

    // Na stroji běží playerctld, takže Mpris.players vrací Firefox dvakrát —
    // jednou přímo a jednou přes proxy org.mpris.MediaPlayer2.playerctld.
    // Bez tohohle filtru by panel ukazoval dva stejné přehrávače.
    readonly property var candidates: Mpris.players.values.filter(function (p) {
        return p && p.dbusName && p.dbusName.indexOf("playerctld") === -1;
    })

    // Přednost má ten, co zrovna hraje; jinak první v seznamu.
    //
    // Původně tu bylo „připnutí" vybraného přehrávače, aby UI neposkakovalo,
    // jenže `pinned` se nastavovalo z `player` a zároveň do něj vstupovalo →
    // Qt to zahlásilo jako binding loop. Čistá odvozená hodnota tenhle problém
    // nemá a na stroji s jedním reálným přehrávačem nic neřeší.
    readonly property var player: {
        const playing = candidates.find(function (p) { return p.isPlaying; });
        return playing || candidates[0] || null;
    }

    readonly property bool hasArt: !!player && !!player.trackArtUrl && player.trackArtUrl.length > 0

    function fmt(seconds) {
        if (!seconds || seconds <= 0)
            return "0:00";
        const s = Math.floor(seconds % 60);
        return Math.floor(seconds / 60) + ":" + (s < 10 ? "0" + s : s);
    }

    // MprisPlayer.position se nemění reaktivně, musí se šťouchat ručně.
    // Podmínka na `open` je zásadní — jinak by to tikalo na každý snímek
    // i se zavřeným panelem.
    FrameAnimation {
        running: section.open && !!section.player && section.player.isPlaying
                 && section.player.length > 0
        onTriggered: if (section.player) section.player.positionChanged()
    }

    Item {
        width: parent.width
        height: 68

        // --- obal alba / placeholder ---
        Item {
            id: art
            width: 68
            height: 68
            anchors.left: parent.left

            HudFrame {
                anchors.fill: parent
                cutTR: Style.chamferXs
                cutBL: Style.chamferXs
                cutTL: 0
                cutBR: 0
                fill: Style.bgSunken
                stroke: section.player ? Style.withAlpha(Style.media, 0.5) : Style.line
            }

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: section.hasArt ? section.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: section.hasArt && status === Image.Ready
            }

            CautionStripe {
                anchors.fill: parent
                anchors.margins: 2
                color: Style.textDim
                stripeOpacity: 0.25
                visible: !section.player
            }

            Text {
                anchors.centerIn: parent
                text: Style.iconMusic
                color: Style.textDim
                font.family: Style.fontFamily
                font.pixelSize: 22
                visible: !section.hasArt
            }
        }

        // --- název, interpret, progress ---
        Item {
            anchors.left: art.right
            anchors.leftMargin: Style.spacingM
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Text {
                id: title
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                text: section.player ? (section.player.trackTitle || section.player.identity)
                                     : "NO SIGNAL"
                color: section.player ? Style.text : Style.textDim
                font.family: Style.fontFamily
                font.pixelSize: Style.fontTitle
                font.letterSpacing: section.player ? 0 : Style.labelSpacing
                elide: Text.ElideRight
            }

            Text {
                id: artist
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: title.bottom
                anchors.topMargin: 2
                text: section.player ? (section.player.trackArtist || "") : ""
                color: Style.textMuted
                font.family: Style.fontFamily
                font.pixelSize: Style.fontBody
                elide: Text.ElideRight
            }

            // Progress: hairline bez Behavior — s per-frame updatem by se praly.
            Rectangle {
                id: progressTrack
                anchors.left: parent.left
                anchors.right: elapsed.left
                anchors.rightMargin: Style.spacingS
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                height: 3
                color: Style.bgSunken
                border.width: 0
                visible: !!section.player && section.player.length > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: (section.player && section.player.length > 0)
                        ? parent.width * Math.min(1, section.player.position / section.player.length)
                        : 0
                    color: Style.media
                    border.width: 0
                }
            }

            Text {
                id: elapsed
                anchors.right: parent.right
                anchors.verticalCenter: progressTrack.verticalCenter
                text: (section.player && section.player.length > 0)
                    ? section.fmt(section.player.position) + " / " + section.fmt(section.player.length)
                    : ""
                color: Style.textDim
                font.family: Style.fontFamily
                font.pixelSize: Style.fontMicro
            }
        }
    }

    // --- transport ---
    Row {
        spacing: Style.spacingS

        HudButton {
            width: 46
            height: 30
            accent: Style.media
            icon: Style.iconPrev
            enabled: !!section.player && section.player.canGoPrevious
            onClicked: section.player.previous()
        }

        HudButton {
            width: 56
            height: 30
            accent: section.player && section.player.isPlaying ? Style.ok : Style.media
            active: !!section.player && section.player.isPlaying
            icon: (section.player && section.player.isPlaying) ? Style.iconPause : Style.iconPlay
            enabled: !!section.player && section.player.canTogglePlaying
            onClicked: section.player.togglePlaying()
        }

        HudButton {
            width: 46
            height: 30
            accent: Style.media
            icon: Style.iconNext
            enabled: !!section.player && section.player.canGoNext
            onClicked: section.player.next()
        }
    }
}
