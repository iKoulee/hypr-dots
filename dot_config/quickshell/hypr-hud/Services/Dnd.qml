pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

// Do-not-disturb režim mako.
//
// TVRDÉ PRAVIDLO: nikdy nevolat `makoctl` přímo. ~/.local/bin/hypr-dnd dělá
// `makoctl mode -t do-not-disturb` A `pkill -RTMIN+8 waybar` — kdyby panel
// skript obešel, indikátor ve waybaru by zůstal na starém stavu až do dalšího
// signálu. Skript je zároveň jediné místo, kde je definovaný kontrakt
// (JSON s klíči text/tooltip/class, class == "dnd" když je DND zapnuté).
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/hypr-dnd"

    property bool active: false
    property string tooltip: ""

    Process {
        id: statusProc
        command: [root.script, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    root.active = (j["class"] === "dnd");
                    root.tooltip = j.tooltip || "";
                } catch (e) {
                    // Když mako neběží, skript sám spadne na „notifikace
                    // zapnuté" — sem se dostaneme jen při skutečné chybě.
                    root.active = false;
                    root.tooltip = "";
                }
            }
        }
    }

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
    }

    function toggle() {
        Quickshell.execDetached([root.script, "toggle"]);
        settle.restart();
    }

    // makoctl i pkill běží asynchronně, hned po spuštění by status vrátil
    // ještě starou hodnotu.
    Timer {
        id: settle
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    // Opačný směr synchronizace: mako o změně režimu nic nevysílá a quickshell
    // 0.3.0 nemá generické D-Bus API, takže se to musí přečíst. Polling zapíná
    // panel, když je otevřený (viz `polling` níž) — se zavřeným neběží nic.
    property bool polling: false
    onPollingChanged: if (polling) refresh()

    Timer {
        interval: 2000
        repeat: true
        running: root.polling
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
