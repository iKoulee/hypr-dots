import QtQuick

import Quickshell

import qs.Commons
import qs.Widgets

// Hlavička panelu: velké hodiny, datum, a vpravo dva ornamentální mikropopisky.
Item {
    id: section

    property bool open: false

    implicitHeight: 92

    // Se zavřeným panelem netikat. precision: Seconds je kvůli blikající
    // dvojtečce — bez ní by stačily Minutes.
    SystemClock {
        id: clock
        enabled: section.open
        precision: SystemClock.Seconds
    }

    Row {
        id: timeRow
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 0

        GlitchText {
            id: hours
            text: Qt.formatDateTime(clock.date, "HH")
            color: Style.text
            baseFringe: 1.5
            font.family: Style.fontFamily
            font.pixelSize: Style.fontDisplay
            font.letterSpacing: 3
            anchors.verticalCenter: parent.verticalCenter
        }

        // Dvojtečka bliká — jediný pravidelný pohyb v celém panelu.
        Text {
            text: ":"
            color: Style.accentHot
            opacity: clock.seconds % 2 === 0 ? 1.0 : 0.35
            font.family: Style.fontFamily
            font.pixelSize: Style.fontDisplay
            anchors.verticalCenter: parent.verticalCenter

            Behavior on opacity { NumberAnimation { duration: Style.durBase } }
        }

        GlitchText {
            text: Qt.formatDateTime(clock.date, "mm")
            color: Style.text
            baseFringe: 1.5
            font.family: Style.fontFamily
            font.pixelSize: Style.fontDisplay
            font.letterSpacing: 3
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: timeRow.bottom
        anchors.topMargin: Style.spacingXs
        // Přes locale, ne natvrdo — datum má být česky. Kdyby systemd service
        // zdědil jiné LANG než terminál, sáhni sem po Qt.locale("cs_CZ").
        text: clock.date.toLocaleDateString(Qt.locale(), "dddd d. MMMM yyyy")
        color: Style.textMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontBody
    }

    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Style.spacingXs
        spacing: Style.spacingXs

        Text {
            anchors.right: parent.right
            text: "HUD//CTRL"
            color: Style.warn
            font.family: Style.fontFamily
            font.pixelSize: Style.fontLabel
            font.letterSpacing: Style.labelSpacing
        }

        Text {
            anchors.right: parent.right
            text: section.QsWindow.window && section.QsWindow.window.screen
                ? section.QsWindow.window.screen.name + " · "
                  + section.QsWindow.window.screen.width + "×"
                  + section.QsWindow.window.screen.height
                : ""
            color: Style.textDim
            font.family: Style.fontFamily
            font.pixelSize: Style.fontMicro
        }
    }
}
