import Quickshell
import Quickshell.Io

import qs.Modules

// Control center „hypr-hud".
//
// POZOR: v tomhle configu se NIKDY neinstancuje NotificationServer.
// Quickshell je plnohodnotný notifikační démon — jméno org.freedesktop.Notifications
// drží mako, takže registrace by teď jen selhala do logu, jenže quickshell to
// jméno SLEDUJE a v okamžiku, kdy mako skončí (třeba `just restart-mako`), by
// se ho tiše zmocnil a notifikace by přestaly chodit. DND se proto ovládá
// přes ~/.local/bin/hypr-dnd, ne přes vlastní server.
//
// Panel se drží jednoho monitoru (stroj má jediný 5120×1440). Kdyby přibyl
// druhý, obal HudPanel do Variants { model: Quickshell.screens }.
ShellRoot {
    id: root

    HudPanel {
        id: hud
    }

    // Vyvolání zvenčí: `qs -c hypr-hud ipc call hud toggle`, obalené
    // v ~/.local/bin/hypr-hud (ten řeší LD_LIBRARY_PATH a nixGL).
    //
    // Anotace typů argumentů i návratu jsou POVINNÉ — bez nich se funkce
    // vůbec nezaregistruje a selže to tiše. Kontrola: `just hud-ipc`.
    IpcHandler {
        target: "hud"

        function toggle(): void { hud.visible = !hud.visible }
        function open(): void   { hud.visible = true }
        function close(): void  { hud.visible = false }
        function state(): string { return hud.visible ? "open" : "closed" }
    }
}
