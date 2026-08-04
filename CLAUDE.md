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
| `dot_config/systemd/user/` | `~/.config/systemd/user/` |
| `dot_local/bin/executable_*` | `~/.local/bin/` (nasazeno jako spustitelné) |
| `dot_local/share/applications/` | `~/.local/share/applications/` |
| `dot_local/share/wallpapers/` | `~/.local/share/wallpapers/` |

`CLAUDE.md` a `justfile` jsou v `.chezmoiignore` — chezmoi je nenasazuje.

## Architecture

### Autostart: systemd user services (preferovaná metoda)

Waybar a hyprpaper jsou spravovány jako **systemd user services**, ne spouštěny přímo z Hyprland configu. Řeší to problém s `PATH` při startu z display manageru a umožňuje `systemctl --user restart waybar` bez zásahu do Hyprlandu.

Startup sekvence v `hl.on("hyprland.start")`:
1. `dbus-update-activation-environment` — exportuje `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `HYPRLAND_INSTANCE_SIGNATURE` do D-Bus (nutné pro XDG portaly a tray)
2. `systemctl --user import-environment` — zpřístupní stejné proměnné všem user services
3. `systemctl --user start hyprland-session.target` — nastartuje waybar a hyprpaper

Unit soubory v `dot_config/systemd/user/`:
- `hyprland-session.target` — seskupuje session services (`Wants=` waybar, hyprpaper)
- `waybar.service` / `hyprpaper.service` — `PartOf=hyprland-session.target`, `Restart=on-failure`

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

Výchozí schéma: **Tokyo Night**. Barvy jsou definovány přímo v jednotlivých CSS/config souborech — zatím bez centrálního token souboru.

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
- `notify-send` je volaný podmíněně. Notifikační démon zatím neběží, takže je to no-op; až přibude, začne fungovat bez zásahu do skriptu.

Waybar `pulseaudio` modul: levý klik = mute toggle, pravý klik = přepínač, scroll = hlasitost, tooltip = název zařízení. Multimediální klávesy (`XF86Audio*`) jsou v `hyprland.lua` a jdou taky přes `wpctl`.

### Input layout

Klávesnice `us,cz`, přepínání `Win+Space` (`kb_options = "grp:win_space_toggle"`).
