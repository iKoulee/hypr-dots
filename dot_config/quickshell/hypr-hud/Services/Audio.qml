pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Zvuk přes nativní PipeWire službu quickshellu — žádné wpctl ani pw-dump
// na čtení. Přezdívky zařízení se ale berou ze stejného souboru jako
// v hypr-audio-menu, ať panel a wofi menu ukazují totéž.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    // Streamy (přehrávače) vypadnou, zůstanou fyzická výstupní zařízení.
    readonly property var sinks: Pipewire.nodes.values.filter(function (n) {
        return n && n.isSink && !n.isStream;
    })

    // POVINNÉ. Bez trackeru jsou volume, muted i properties neplatné —
    // hlasitost by byla pořád 0 a všechna zařízení by spadla na fallback
    // název, protože node.name by nešel přečíst. Trackují se všechny sinky,
    // ne jen výchozí: čipy potřebují node.name i u neaktivních.
    PwObjectTracker {
        objects: root.sink ? root.sinks.concat([root.sink]) : root.sinks
    }

    // defaultAudioSink může být přechodně null (dokumentovaná vlastnost),
    // takže všude opatrně.
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted:  (sink && sink.audio) ? sink.audio.muted  : false
    readonly property bool ready:  sink !== null && sink !== undefined

    function setVolume(v) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function isDefault(node) {
        return !!node && !!sink && node.id === sink.id;
    }

    // ---- přezdívky z ~/.config/hypr-audio/devices.conf -------------------
    //
    // Formát `glob|ikona|název`, # je komentář, první shoda vyhrává — stejná
    // sémantika jako bashový `while read` v hypr-audio-menu. Tenhle soubor má
    // tedy dva konzumenty a změna formátu se musí promítnout do obou.
    //
    // watchChanges znamená, že editace se projeví bez restartu služby.
    property var rules: []

    FileView {
        // FileView.path neexpanduje ~, proto přes Quickshell.env.
        path: Quickshell.env("HOME") + "/.config/hypr-audio/devices.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rules = root.parseDevices(this.text())
        onLoadFailed: root.rules = []      // soubor nemusí existovat
    }

    // Glob → RegExp: escapovat všechno kromě * a ?, ty pak přeložit.
    function globToRegExp(glob) {
        const escaped = glob.replace(/[.+^${}()|[\]\\]/g, "\\$&")
                            .replace(/\*/g, ".*")
                            .replace(/\?/g, ".");
        return new RegExp("^" + escaped + "$");
    }

    function parseDevices(txt) {
        const out = [];
        const lines = (txt || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0 || line.charAt(0) === "#")
                continue;
            const parts = line.split("|");
            if (parts.length < 3 || parts[2].trim().length === 0)
                continue;
            out.push({
                re: globToRegExp(parts[0].trim()),
                icon: parts[1],
                label: parts[2].trim()
            });
        }
        return out;
    }

    // Vrátí { icon, label }. Ikona v devices.conf bývá prázdná (glyfy se z něj
    // někdy ztratily), takže se na ni nespoléhá a volající si doplní svou.
    function describe(node) {
        if (!node)
            return { icon: "", label: "—" };

        const props = node.properties || {};
        const name = props["node.name"] || node.name || "";

        for (let i = 0; i < rules.length; i++) {
            if (rules[i].re.test(name))
                return { icon: rules[i].icon, label: rules[i].label };
        }
        return { icon: "", label: node.description || node.nickname || name };
    }
}
