# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A full Hyprland dotfiles setup managed via **chezmoi**. Covers Hyprland (Wayland compositor), Waybar (panel), Wofi (app launcher), systemd user services, and startup scripts. Installed via Nix on a non-NixOS system with an NVIDIA GPU and a 5120×1440 ultrawide monitor. Default color scheme: **Tokyo Night**.

## Deployment

### Prerequisites

```bash
nix-env -iA nixpkgs.chezmoi nixpkgs.just
```

### First install on a new machine

```bash
chezmoi init https://github.com/iKoulee/hypr-dots
just bootstrap        # chezmoi apply + systemctl enable
```

### Common commands

```bash
just diff             # co by se změnilo
just apply            # nasadit změny
just reload           # reload Hyprland (bez restartu)
just restart-waybar   # restart panelu
just --list           # přehled všech příkazů
```

## Repo structure (chezmoi conventions)

| Zdroj | Cíl |
|-------|-----|
| `dot_config/hypr/` | `~/.config/hypr/` |
| `dot_config/waybar/` | `~/.config/waybar/` |
| `dot_config/wofi/` | `~/.config/wofi/` |
| `dot_config/mako/` | `~/.config/mako/` |
| `dot_config/systemd/user/` | `~/.config/systemd/user/` |
| `dot_local/bin/executable_*` | `~/.local/bin/` (nasazeno jako spustitelné) |
| `dot_local/share/applications/` | `~/.local/share/applications/` |
| `dot_local/share/wallpapers/` | `~/.local/share/wallpapers/` |
| `dot_local/share/dbus-1/services/` | `~/.local/share/dbus-1/services/` |

`CLAUDE.md`, `README.md` a `justfile` jsou v `.chezmoiignore` — chezmoi je nenasazuje.
Tamtéž je i `.config/keepassxc` (obsahuje privátní KeeShare klíč a stav), takže KeePassXC
se konfiguruje ručně v GUI — kroky jsou v `README.md`.

## Architecture

### Autostart: systemd user services (preferovaná metoda)

Waybar, hyprpaper, mako, keepassxc a hyprpolkitagent jsou spravovány jako **systemd user services**, ne spouštěny přímo z Hyprland configu. Řeší to problém s `PATH` při startu z display manageru a umožňuje `systemctl --user restart waybar` bez zásahu do Hyprlandu.

Startup sekvence v `hl.on("hyprland.start")`:
1. `dbus-update-activation-environment` — exportuje `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `HYPRLAND_INSTANCE_SIGNATURE` do D-Bus (nutné pro XDG portaly a tray)
2. `systemctl --user import-environment` — zpřístupní stejné proměnné všem user services (včetně `SSH_AUTH_SOCK`, viz sekce Keyring a hesla)
3. `systemctl --user start hyprland-session.target` — nastartuje všechny session services

Unit soubory v `dot_config/systemd/user/`:

- `hyprland-session.target` — seskupuje session services (`Wants=` waybar, hyprpaper, mako, keepassxc, hyprpolkitagent)
- `waybar.service` / `hyprpaper.service` / `mako.service` / `keepassxc.service` / `hyprpolkitagent.service` — `PartOf=hyprland-session.target`, `Restart=on-failure`

Nová service pro autostart: vytvoř `.service` s `WantedBy=hyprland-session.target`, přidej ji
do `Wants=` v targetu **a do seznamů v `enable-services`/`disable-services` v `justfile`** —
jsou tři ručně udržované seznamy a musí sedět všechny. Pokud jde o nixovou GUI aplikaci,
patří do ní i `UnsetEnvironment=LD_LIBRARY_PATH` (viz sekce Keyring a hesla).

### Hyprland config: Lua API

Aktivní config je `dot_config/hypr/hyprland.lua` (Hyprland Lua API). `hyprland.conf.bak` je starý INI formát ponechaný pro referenci — needitovat.

Klíčové Lua API vzory:
- `hl.config({...})` — nastavení proměnných (obdoba INI sekcí)
- `hl.bind(...)` — klávesové zkratky
- `hl.window_rule({...})` — pravidla pro okna
- `hl.animation({...})` / `hl.curve(...)` — animace
- `hl.on("hyprland.start", fn)` — autostart hook

**Zdroj pravdy pro Lua API je LSP stub, ne wiki.** Hyprland nasazuje do nix profilu
`~/.nix-profile/share/hypr/stubs/hl.meta.lua` — kompletní `HL.API` (všechny funkce),
`HL.*Spec` třídy s validními poli každého pravidla a `hl.dsp.*` namespace. Sleduje
nainstalovanou verzi, zatímco wiki je pro 0.56 místy pozadu a neúplná.

```bash
grep -n "HL.WorkspaceRuleSpec\|HL.WindowRuleSpec\|HL.ConfigOpt" ~/.nix-profile/share/hypr/stubs/hl.meta.lua
```

Doplňkově `hyprctl descriptions` — vypíše všechny config options s defaulty, rozsahy
a popisem (stub dává tvar API, `descriptions` konkrétní klíče a hodnoty):

```bash
hyprctl descriptions | jq -r '.[] | "\(.name)  def=\(.default)  \(.description)"'
```

Pro doplňování v editoru nasměruj lua-language-server na adresář `stubs/`.

**Vlastní layout jde napsat v Lua**, plugin není potřeba — `hl.layout.register(jméno, provider)`,
provider má `recalculate(ctx)` a volitelně `layout_msg(ctx, msg)`. `ctx:column(i, n)` vrátí
i-tý z n stejně širokých sloupců, `ctx:row`, `ctx:grid_cell` analogicky; `target:place(box)`
okno umístí a gapy si Hyprland dopočítá sám nad vráceným boxem. Vlastní layout `thirds`
(sloupce po třetinách) je v `dot_config/hypr/hyprland.lua`. Dvě pasti:

- **Registrované jméno dostane prefix `lua:`** — `general.layout` musí být `"lua:thirds"`.
  Na neznámé jméno Hyprland tiše spadne na dwindle, bez hlášky v logu; poznáš to jen podle
  geometrie (dwindle dá na třech oknech 50/25/25).
- **Druhá registrace stejného jména hodí chybu a utne vyhodnocení zbytku configu.** Proto je
  volání obalené `pcall`, aby reload prošel. Důsledek: tělo `recalculate` se za běhu už
  nepřepíše — změny se projeví až po restartu Hyprlandu. Iterovat se dá registrací pod
  jiným jménem přes `hyprctl dispatch`.

**Pozor na `hyprctl dispatch` v 0.56** — bere Lua, ne starou syntaxi (`exec [workspace 9 silent] kitty`
skončí na parse error). Dispatchery jako `hl.dsp.window.close()` nebo `hl.dsp.window.move({…})`
působí na **aktivní okno** a nemají cílový argument, takže při živém fokusu klidně trefí něco
jiného, než čekáš. Tvary argumentů se dají bezpečně zjistit chybovou hláškou — `hl.dsp.focus({ __probe = 1 })`
vypíše `Expected one of: direction, monitor, window, …` a nic neprovede. `hl.dsp.window.close()`
takhle **bezpečné není**, neznámé argumenty ignoruje a okno zavře.

**Layout není globálně exkluzivní.** `general.layout` je jen default; `hl.workspace_rule`
má pole `layout` a `layout_opts` (viz `HL.WorkspaceRuleSpec` ve stubu), takže jde mít
jiný layout per workspace. Klíče v `layout_opts` jsou bez prefixu (`column_width`, ne
`scrolling:column_width`). Za běhu se globální layout přepnout nedá — `hyprctl keyword`
s Lua configem zmizel (vrací `unknown request`), takže změna = editace `hyprland.lua`
a `just reload`.

### NVIDIA + Nix startup

`dot_local/bin/executable_start-hyprland-nix` (nasazeno jako `~/.local/bin/start-hyprland-nix`):
- Přidává `~/.nix-profile/bin` na začátek `PATH` — klíčové při startu z display manageru, bez toho `exec_cmd` volání v Lua configu tiše selžou
- Nastavuje NVIDIA/Wayland env proměnné (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, …)
- Spouští `~/.nix-profile/bin/Hyprland`

### Color scheme

Barvy jsou definovány přímo v jednotlivých CSS/config souborech — zatím bez centrálního token souboru. **Schéma není jednotné:**

- `dot_config/mako/config` — **Tokyo Night** (`#1a1b26`, `#c0caf5`, `#7aa2f7`)
- `dot_config/waybar/style.css`, `dot_config/wofi/style.css` — fakticky **Catppuccin Mocha** (`#1e1e2e`, `#cdd6f4`, `#89b4fa`), přestože dřívější verze tohoto souboru tvrdila Tokyo Night

Při úpravách drž barvy konzistentní v rámci jednoho souboru; sjednocení palety napříč komponentami zatím nikdo neudělal.

### Tapeta (hyprpaper)

`dot_config/hypr/hyprpaper.conf`, démon jede jako `hyprpaper.service`. Od **0.8.0** (přepis
na hyprtoolkit) je `wallpaper` hyprlang *special category*, ne jednořádkový klíč, a `preload`
zmizel úplně — jak z configu, tak z IPC (`hyprctl hyprpaper preload …` → `error: invalid
hyprpaper request`, viz [gitfudge0/walt#27](https://github.com/gitfudge0/walt/issues/27)).

```
wallpaper {
    monitor = DP-2
    path = ~/.local/share/wallpapers/…jpg   # tilda se expanduje
    fit_mode = cover                        # výchozí; dál timeout, order, recursive
}
```

**Starý formát selže tiše** — config se načte, neznámé klíče se zahodí a jediná stopa je
`Monitor DP-2 has no target: no wp will be created` v `journalctl --user -u hyprpaper`.
Service běží, exit code 0, jen není tapeta. Kontrola je `hyprctl hyprpaper listactive`
(prázdný výstup = nenamapováno). Další klíče mimo blok: `splash`, `splash_offset`,
`splash_opacity`, `ipc`, `source`.

`just restart-hyprpaper` po změně configu.

**hyprpaper stojí na `LD_LIBRARY_PATH`.** Renderuje přes aquamarine/hyprtoolkit, takže
potřebuje systémový GBM/EGL stack z `/usr/lib/x86_64-linux-gnu`. Nixová mesa hledá GBM
backendy v `/run/opengl-driver/lib/gbm`, což je NixOS-only cesta a na tomhle stroji
neexistuje — bez `LD_LIBRARY_PATH` skončí na `MESA-LOADER: failed to open …` a spadne
na `SIGABRT`. Naměřeno:

| env | výsledek |
|-----|----------|
| `LD_LIBRARY_PATH` + `GBM_BACKEND` | OK |
| `LD_LIBRARY_PATH`, bez `GBM_BACKEND` | OK — nese to `LD_LIBRARY_PATH`, ne `GBM_BACKEND` |
| `GBM_BACKEND`, bez `LD_LIBRARY_PATH` | ABRT, `MESA-LOADER: failed to open nvidia-drm` |
| `GBM_BACKENDS_PATH`, bez `LD_LIBRARY_PATH` | ABRT — projde GBM loader, padne na `eglCreateImageKHR` |

Z toho plyne přímý **konflikt s pravidlem v sekci Keyring a hesla**: nixové Qt aplikace
potřebují `UnsetEnvironment=LD_LIBRARY_PATH`, hyprpaper naopak spadne. Rozhoduje se to
per-service — do `hyprpaper.service` ten řádek **nepatří**.

`GBM_BACKENDS_PATH` ze `start-hyprland-nix` je mrtvá proměnná: chybí v obou seznamech ve
start hooku, takže se do systemd services nedostane, a podle tabulky výše by `LD_LIBRARY_PATH`
stejně nenahradila.

Historická poznámka: smyčka ~37 core dumpů 4. 8. 2026 mezi 17:14 a 17:18 byla stav **před**
commitem `dcbd90b`, který `LD_LIBRARY_PATH` do start hooku doplnil — ne race při startu.

### Waybar

`dot_config/waybar/config` je JSON. Moduly: workspaces (vlevo), clock (střed), tray/cpu/memory/network/language/pulseaudio (vpravo). Vyžaduje **JetBrainsMono Nerd Font**.

### App launcher

`Super+D` → `wofi --show drun` (konfigurováno v `dot_config/wofi/`). `Super+R` → `hyprlauncher` (musí být nainstalován zvlášť).

### Audio

Stack je **PipeWire/WirePlumber**, ovládá se přes `wpctl`. **`pactl` na stroji není** — nesahat po pulseaudio nástrojích. Výstup `wpctl status` je lokalizovaný podle locale, takže **se neparsuje**; pro strojové čtení stavu použij `pw-dump | jq` (obojí je systémové).

`dot_local/bin/executable_hypr-audio-menu` (nasazeno jako `~/.local/bin/hypr-audio-menu`) — přepínač audio zařízení přes wofi:
- `hypr-audio-menu [output|input]` — `output` (výchozí) přepíná sinky, `input` mikrofony. Rozdíl je jen v `media.class` a metadata klíči, logika je společná.
- Zkratka `Super+Shift+A` je navázaná jen na `output`; bind pro `input` stačí doplnit jedním řádkem v `hyprland.lua`.
- Přezdívky zařízení jsou **data v `dot_config/hypr-audio/devices.conf`**, ne v skriptu. Formát `glob|ikona|název`, glob se porovnává s `node.name`, první match vyhrává. Nenamatchované zařízení spadne na `node.description` + generickou ikonu.
- Skript volá jen `wpctl set-default`. Běžící streamy přesouvat netřeba — WirePlumber má `linking.follow-default-target = true` (ověř přes `wpctl settings`), takže nepinnuté streamy následují změnu samy.
- `notify-send` je volaný podmíněně. Od zavedení mako (viz sekce Notifikace) se notifikace při přepnutí zařízení reálně zobrazí.

Waybar `pulseaudio` modul: levý klik = mute toggle, pravý klik = přepínač, scroll = hlasitost, tooltip = název zařízení. Multimediální klávesy (`XF86Audio*`) jsou v `hyprland.lua` a jdou taky přes `wpctl`.

### Notifikace

Démon je **mako** (`nix profile install nixpkgs#mako`), spouštěný jako systemd user service `mako.service` navěšená na `hyprland-session.target` — stejný vzor jako waybar a hyprpaper. Bez něj je `notify-send` no-op (což byl stav před jeho zavedením, viz podmíněné volání v `hypr-audio-menu`).

Config `dot_config/mako/config`, dokumentace `man 5 mako`:
- `anchor=top-center` — na 5120×1440 je výchozí top-right mimo zorné pole
- `outer-margin=40,10,10,10` — horních 40 px si bere waybar (`height` v `dot_config/waybar/config`); **při změně výšky panelu je potřeba upravit i tohle**
- `layer=top` — notifikace nejdou přes fullscreen okna; pro opak `layer=overlay`
- criteria podle `urgency`; kritické mají `default-timeout=0`, takže nezmizí samy
- `on-button-left=dismiss` — pozor, s `actions=1` tím jsou akce notifikací nedostupné; pro jejich zpřístupnění změň na `invoke-default-action`

Režim **do-not-disturb** je mako *mode* (`[mode=do-not-disturb] invisible=1`), kritické notifikace přes něj projdou díky druhé criteria sekci.

`dot_local/bin/executable_hypr-dnd` (nasazeno jako `~/.local/bin/hypr-dnd`) — sdílený skript pro waybar i keybind:
- `hypr-dnd status` → jeden řádek JSON pro custom modul `custom/dnd` ve waybaru
- `hypr-dnd toggle` → `makoctl mode -t do-not-disturb` + `pkill -RTMIN+8 waybar`
- Waybar modul má `interval: once` a `signal: 8` — žádný polling, překresluje se jen na signál ze skriptu. **Číslo signálu musí sedět na `WAYBAR_SIGNAL` ve skriptu.**
- Když mako neběží, `status` spadne na „notifikace zapnuté" místo aby selhal.

Keybindy v `hyprland.lua` (`makoctl` volaný absolutní cestou přes `nixBin`, stejný důvod jako u wofi):

| Zkratka | Akce |
|---------|------|
| `Super+N` | zavřít poslední notifikaci |
| `Super+Shift+N` | zavřít všechny |
| `Super+Ctrl+N` | vyvolat poslední z historie |
| `Super+Alt+N` | přepnout do-not-disturb |

`just restart-mako` po změně configu, `just test-notify` pro vizuální kontrolu všech tří úrovní priority.

### Screenshoty

Stack je **grim** (snímek) + **slurp** (výběr myší) + **satty** (anotace) + `wl-copy`,
vše z nixu (`nix profile install nixpkgs#grim nixpkgs#slurp nixpkgs#satty`). Portál se
obchází — grim mluví se screencopy protokolem přímo.

`dot_local/bin/executable_hypr-screenshot` (nasazeno jako `~/.local/bin/hypr-screenshot`):

- `hypr-screenshot [region|window|monitor|screen|pick] [save|edit]` — dvě poziční hodnoty,
  stejný idiom jako `hypr-audio-menu`. `save` uloží soubor, zkopíruje do schránky a pošle
  notifikaci; `edit` pošle snímek do satty, kde uložení a kopírování udělá až Enter.
- `hypr-screenshot hint [show|edit|hide]` — nápověda k submapu, volá ji `hl.on("keybinds.submap")`
- `hypr-screenshot last` — cesta k poslednímu snímku
- Cíl je `$(xdg-user-dir PICTURES)/Screenshots`, na tomhle stroji `~/Obrázky/Screenshots`.
  Poslední komponenta je schválně bez diakritiky kvůli globu a cestám v justfile.
- Barvy výběru (slurp) a satty jsou **Tokyo Night**, aby ladily s mako notifikací, která
  po uložení ukáže náhled. Config satty je `dot_config/satty/config.toml`.

| Zkratka | Akce |
|---------|------|
| `Print` | otevře submap `screenshot` |
| `Print` → `R` | výřez myší |
| `Print` → `W` | aktivní okno |
| `Print` → `M` | monitor s fokusem |
| `Print` → `A` | celá plocha (všechny monitory) |
| `Print` → `P` | výběr okna myší ze seznamu |
| `Print` → `E` → `R`/`W`/`M`/`A`/`P` | totéž, ale do satty (Enter uloží a zkopíruje) |
| `Print` → `Esc` nebo `Print` | odchod ze submapu (jiná klávesa ho nezavře, viz pasti) |

`just screenshot` / `just screenshot-edit` pro test bez zkratky, `just screenshots` otevře
adresář.

Pasti:

- **`hl.define_submap(jméno, reset, fn)`** — druhý argument je *jméno submapu, do kterého
  se skočí po vykonání libovolného bindu uvnitř*, ne klávesa. `"reset"` = návrat do default.
  Ověřeno v `src/config/lua/bindings/LuaBindingsToplevel.cpp`, wiki to nemá.
- **`pcall` tu potřeba není**, na rozdíl od `hl.layout.register` — reload zahazuje keybindy
  i celý Lua stav, takže se nic neregistruje dvakrát a tělo submapu se za běhu přepíše.
- **`catchall` s Lua bindy nepoužívat — spustí se navíc, ne až když nic netrefí.**
  V porovnávací smyčce `handleKeybinds` se `found` pro běžný bind nenastaví (nastavuje ho
  až druhá smyčka, která spouští dispatchery), takže strážce `if (found || …)` u catchallu
  je vždy nepravdivý a catchall skončí v `bindsHit` **spolu** s trefeným bindem — a protože
  je registrovaný poslední, doběhne po něm. U snímků to není vidět (reset do default je
  stejně žádoucí), ale přechod `Print` → `E` → `screenshot-edit` tím okamžitě spadl zpátky
  do default a submap přestal reagovat. Zvláštní větev `if (k->handler == "submap") break;`,
  která by tomu zabránila, se na Lua bindy nevztahuje: ty hlásí handler `__lua`
  (`hyprctl binds` je ukazuje jako `dispatcher=__lua`), ne `submap`.
  **Odchod ze submapu proto zařizuje `reset` argument `define_submap`** — po bindu, který
  submap sám nezměnil, se Hyprland vrátí do default. Snímek tak submap zavře, zatímco `E`
  (mění submap) v něm zůstane. Cenou je, že neznámá klávesa submap nezavře; proto nápověda
  visí s timeoutem 0 a připomíná `Esc`.
- **Uvnitř submapu žádné modifikátory** — Hyprland nefiltruje samostatné stisky
  modifikátorů, takže Shift stisknutý před klávesou má nejistý `modmask`. Proto je
  „do editoru" **druhý submap**, ne Shift.
- **`hl.dsp.exec_cmd` posílá stdout i stderr do `/dev/null`** (`Executor.cpp`) — selhaný
  keybind mlčí. Ladit se musí z terminálu, případně dočasně `exec 2> >(logger -t hypr-screenshot)`
  na začátku skriptu a číst `journalctl -t hypr-screenshot -f`.
- **`slurp` bez `</dev/null` může viset** — když stdin není TTY (a z keybindu není), čte
  z něj předdefinované obdélníky.
- **`.visible` v `hyprctl clients` neznamená „na aktuální ploše"** — okna na neaktivních
  workspace hlásí `visible=true`. Filtruje se přes `activeWorkspace.id` z `hyprctl monitors`.
- **Časové razítko má rozlišení na sekundy**, takže dva snímky za sebou by se srazily.
  Skript proto při kolizi přidá `-2`, `-3`… (naměřeno, ne teoretická obava).
- **grim snímá oblast obrazovky, ne okno.** V režimech `window`/`pick` se do snímku dostane
  cokoli, co cílové okno překrývá. `grim -T` (foreign toplevel) by to řešil, ale hyprctl
  potřebný handle nevystavuje.
- **Nativní `hl.notification.create` se kreslí u pravého okraje monitoru** a pozice se
  nekonfiguruje → na 5120×1440 mimo zorné pole. Proto jde nápověda přes mako. Zavírá se
  adresně přes `makoctl dismiss -n <id>` (ID z `notify-send -p`), protože `dismiss` bez `-n`
  by trefil poslední notifikaci — a tou už může být hláška o uloženém snímku.
- **`hl.permission` je no-op**, dokud je `ecosystem:enforce_permissions` vypnuté (default
  `false`), a pravidla se aplikují jen při prvním načtení configu — `just reload` je
  neprojeví. Zakomentované příklady v `hyprland.lua` míří na `/nix/store/[^/]+/…`, ne na
  `/usr/bin`, protože tady jde všechno z nixu.
- **Známé omezení: `xdg-desktop-portal-hyprland` neběží.** Systemd user `XDG_DATA_DIRS`
  neobsahuje `~/.nix-profile/share`, takže systémový portál nenajde `hyprland.portal` a jede
  jen `-gtk`. Screenshot a sdílení obrazovky **z prohlížeče** proto nefungují; `hypr-screenshot`
  portál nepotřebuje. Oprava = propagace `XDG_DATA_DIRS` + nová service do všech tří seznamů,
  samostatná změna.

Kontrola po změně submapu:

```bash
hyprctl binds -j | jq -r '.[] | select(.submap | startswith("screenshot")) | "\(.submap)\t\(.key)\t\(.dispatcher)"'
```

Očekává se 8 bindů v `screenshot` (E R W M A P escape Print) a 7 v `screenshot-edit`.
Za běhu `hyprctl submap` — po `Print` musí vrátit `screenshot`, po `E` pak `screenshot-edit`.

Na rozdíl od hyprpaperu a KeePassXC **satty žádné zvláštní zacházení s `LD_LIBRARY_PATH`
nepotřebuje** — ověřeno, se session hodnotou `/usr/lib/x86_64-linux-gnu` naběhne v pořádku
(GTK4 4.22.4 v nixu i systému, a GTK nemá runtime kontrolu verzí jako Qt).

### Keyring a hesla

Password manager je **KeePassXC**, spouštěný jako `keepassxc.service` na
`hyprland-session.target` (stejný vzor jako waybar/mako). Zároveň je to poskytovatel
Secret Service — vlastní `org.freedesktop.secrets`, které dřív držel gnome-keyring.
`Super+Shift+K` vyvolá okno (aplikace je single-instance, běží schovaná v trayi).

**KeePassXC musí být z nixu, ne ze snapu.** Ověřeno v
`/var/lib/snapd/apparmor/profiles/snap.keepassxc.keepassxc`: snap smí bindovat jen
`org.keepassxc.KeePassXC.MainWindow` a `org.kde.StatusNotifierItem-*`, takže Secret
Service jméno vlastnit nemůže, a z `/run/user/1000/` vidí jen svůj `snap.keepassxc/`
adresář, takže nedosáhne na ssh-agent socket. Obojí je tichý fail, ne chybová hláška.

**Past: `LD_LIBRARY_PATH` vs. nix binárky.** `start-hyprland-nix` kvůli NVIDII nastavuje
`LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` a `hyprland.lua` ho posílá do systemd přes
`import-environment`. Nixová Qt aplikace si pak natáhne systémové Qt a spadne
(`requires Qt 5.15.19, found Qt 5.15.18`). Postižené je **všechno v session**, ne jen
systemd — terminály, keybindy i D-Bus aktivované procesy. Řeší se to na dvou místech:

- `keepassxc.service` a `hyprpolkitagent.service` mají v `[Service]` řádek
  `UnsetEnvironment=LD_LIBRARY_PATH`, takže nezávisí na `~/.local/bin`
- `dot_local/bin/executable_keepassxc` je shim, který proměnnou odstraní a předá řízení
  nixové binárce. `~/.local/bin` je v `PATH` **před** `~/.nix-profile/bin`, takže stíní
  i holé `keepassxc` napsané v terminálu. Na shim míří keybind `Super+Shift+K`
  i `Exec=` v D-Bus service souboru — proto **ne** přes `nixBin`, na rozdíl od wofi
  a makoctl.

**Každá další nixová Qt/GTK aplikace bude potřebovat obojí.**

Druhá past: `hyprpolkitagent` se instaluje do `libexec/`, ne do `bin/`, takže
v `~/.nix-profile/bin/` není — `ExecStart` míří na `%h/.nix-profile/libexec/hyprpolkitagent`.

Secret Service se přepíná dvěma soubory:

- `dot_config/systemd/user/gnome-keyring-daemon.service.d/override.conf` — nechává
  gnome-keyringu jen `pkcs11` (certifikátové úložiště), `secrets` mu odebírá
- `dot_local/share/dbus-1/services/org.freedesktop.secrets.service.tmpl` — user-level
  D-Bus aktivace stíní systémovou z `/usr/share/dbus-1/services/`. D-Bus service soubory
  neumí `%h`, proto chezmoi template s `{{ .chezmoi.homeDir }}`.

Kontrolní bod je `busctl --user list | grep org.freedesktop.secrets` — musí ukazovat na
keepassxc. Skupina vystavená přes Secret Service je nastavení v databázi, ne v configu;
bez ní je služba na D-Bus, ale nevrací žádnou kolekci (`Collections` → `ao 0`).

Při přechodu **se stará hesla z `login.keyring` nemigrovala** — vědomé rozhodnutí. Zbyly
tam nedostupné a to včetně Chrome/Chromium/Vivaldi Safe Storage klíčů, takže uložená
hesla v prohlížečích jsou pryč.

SSH agent: gcr-ssh-agent je maskovaný a místo něj jede `ssh-agent.socket`
(`/run/user/1000/openssh_agent`), protože do gcr agenta KeePassXC klíče vkládat neumí.
`SSH_AUTH_SOCK` se nastavuje ve `start-hyprland-nix` — musí to být tam, GDM/PAM ho nastaví
dřív než Hyprland — a zároveň musí být v obou seznamech ve start hooku
(`dbus-update-activation-environment` i `import-environment`), jinak ho user services
neuvidí. Přepnutí dělá `just enable-keyring-integration` (stav stroje, ne chezmoi),
rollback `just disable-keyring-integration`. **Vedlejší efekt: gnome-keyring už
automaticky nenačítá klíče z `~/.ssh`** — buď patří do KeePassXC databáze, nebo se
načtou ručně přes `ssh-add`.

Browser integrace: `~/.mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json`
míří na `~/.nix-profile/bin/keepassxc-proxy`. **Se snap Firefoxem to nefunguje** — jeho
AppArmor profil povoluje exec v `$HOME` jen pro cesty nezačínající tečkou
(`owner @{HOME}/[^s.]** rwklix`) a pro `/nix/store` nemá pravidlo žádné. Řešení je
Firefox mimo snap.

### Input layout

Klávesnice `us,cz`, přepínání `Win+Space` (`kb_options = "grp:win_space_toggle"`).
