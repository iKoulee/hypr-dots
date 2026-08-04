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

`CLAUDE.md` a `justfile` jsou v `.chezmoiignore` — chezmoi je nenasazuje.

## Architecture

### Autostart: systemd user services (preferovaná metoda)

Waybar, hyprpaper a mako jsou spravovány jako **systemd user services**, ne spouštěny přímo z Hyprland configu. Řeší to problém s `PATH` při startu z display manageru a umožňuje `systemctl --user restart waybar` bez zásahu do Hyprlandu.

Startup sekvence v `hl.on("hyprland.start")`:
1. `dbus-update-activation-environment` — exportuje `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `HYPRLAND_INSTANCE_SIGNATURE` do D-Bus (nutné pro XDG portaly a tray)
2. `systemctl --user import-environment` — zpřístupní stejné proměnné všem user services
3. `systemctl --user start hyprland-session.target` — nastartuje waybar, hyprpaper a mako

Unit soubory v `dot_config/systemd/user/`:
- `hyprland-session.target` — seskupuje session services (`Wants=` waybar, hyprpaper, mako)
- `waybar.service` / `hyprpaper.service` / `mako.service` — `PartOf=hyprland-session.target`, `Restart=on-failure`

Nová service pro autostart: vytvoř `.service` s `WantedBy=hyprland-session.target` a přidej ji do `Wants=` v targetu.

### Hyprland config: Lua API

Aktivní config je `dot_config/hypr/hyprland.lua` (Hyprland Lua API). `hyprland.conf.bak` je starý INI formát ponechaný pro referenci — needitovat.

Klíčové Lua API vzory:
- `hl.config({...})` — nastavení proměnných (obdoba INI sekcí)
- `hl.bind(...)` — klávesové zkratky
- `hl.window_rule({...})` — pravidla pro okna
- `hl.animation({...})` / `hl.curve(...)` — animace
- `hl.on("hyprland.start", fn)` — autostart hook

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

### Input layout

Klávesnice `us,cz`, přepínání `Win+Space` (`kb_options = "grp:win_space_toggle"`).
