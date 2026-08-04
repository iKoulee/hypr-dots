# hypr-dots

Hyprland dotfiles (Hyprland, Waybar, Wofi, systemd user services) nasazované přes [chezmoi](https://www.chezmoi.io/). Architektura a konvence repa jsou popsané v `CLAUDE.md`.

## Prerekvizity

- Nix (balíčkovací systém) — na tomto stroji je Nix v novém `nix profile` režimu, ne starém `nix-env`
- SSH klíč zaregistrovaný na GitHubu (repo se klonuje/pushuje přes SSH: `git@github.com:iKoulee/hypr-dots.git`)
- PipeWire/WirePlumber včetně `wpctl` a `pw-dump`, plus `jq` — používá je přepínač audio výstupů `~/.local/bin/hypr-audio-menu` (`Super+Shift+A`, nebo `just audio`). Na běžné distribuci jsou to systémové balíčky, čerstvá instalace je ale mít nemusí.

## Instalace chezmoi + just

```bash
nix profile install nixpkgs#chezmoi nixpkgs#just
```

> Pokud `nix-env -iA nixpkgs.chezmoi nixpkgs.just` skončí chybou `profile ... is incompatible with 'nix-env'`, znamená to, že profil byl vytvořen novým `nix profile` nástrojem — použij příkaz výše.

Binárky se nainstalují do `~/.nix-profile/bin`. Ujisti se, že je tento adresář na `PATH` (v interaktivním shellu obvykle ano díky Nix profilu; pokud ne):

```bash
export PATH="$HOME/.nix-profile/bin:$PATH"
```

## Nasazení na čerstvý stroj (repo ještě nikde není naklonované)

```bash
chezmoi init git@github.com:iKoulee/hypr-dots.git
just bootstrap        # chezmoi apply + systemctl enable waybar/hyprpaper
```

`chezmoi init` naklonuje repo do výchozího source adresáře `~/.local/share/chezmoi`.

## Nasazení, když repo je už lokálně naklonované jinam

Tohle je případ tohoto stroje: repo bylo naklonované na `~/repos/GitHub/iKoulee/hypr-dots` a chezmoi bez inicializace o něm nic neví (výchozí source dir `~/.local/share/chezmoi` neexistuje).

1. Nasměruj chezmoi source dir na existující klon (bez nového klonování):

   ```bash
   chezmoi init --source ~/repos/GitHub/iKoulee/hypr-dots
   ```

   `--source` ale platí jen pro tento konkrétní příkaz, nezapisuje se natrvalo do configu. Aby `just diff`/`just apply` (které volají čistě `chezmoi diff`/`chezmoi apply` bez `--source`) fungovaly i příště, vytvoř symlink na výchozí cestu:

   ```bash
   mkdir -p ~/.local/share
   ln -s ~/repos/GitHub/iKoulee/hypr-dots ~/.local/share/chezmoi
   ```

2. Zkontroluj, co se změní, a nasaď:

   ```bash
   just diff
   just apply
   ```

   > **Pozor:** pokud v `~/.config` existují staré symlinky na jiné dotfiles (např. z dřívějšího ručního nasazení), `chezmoi apply` je nahradí reálnými soubory z tohoto repa. Před `apply` se `just diff` vždy podívej, co se přepíše.

3. Povol a nastartuj systemd user services (waybar, hyprpaper):

   ```bash
   just enable-services
   ```

## Běžné příkazy

```bash
just diff             # co by se změnilo
just apply            # nasadit změny
just status           # aktuální stav nasazených souborů
just reload            # reload Hyprlandu bez restartu
just restart-waybar    # restart panelu
just enable-services   # systemctl --user enable --now waybar hyprpaper
just disable-services  # systemctl --user disable --now waybar hyprpaper
just bootstrap          # apply + enable-services (první nasazení)
just --list             # přehled všech příkazů
```

## Aktualizace po změně dotfiles

Po editaci souborů v tomto repu (ať přímo, nebo přes `chezmoi edit`):

```bash
just diff
just apply
```

Systemd services (`waybar.service`, `hyprpaper.service`) mají `PartOf=hyprland-session.target` a `Restart=on-failure`, takže po `apply` je často potřeba restart jen konkrétní služby (`just restart-waybar`), ne celého Hyprlandu.

## Push změn do repa

```bash
git add -A
git commit -m "…"
git push
```

Chezmoi source dir (symlink na `~/repos/GitHub/iKoulee/hypr-dots`, viz výše) je stejný git repo jako pracovní kopie — commit/push se dělá běžně v tomto adresáři, žádný extra chezmoi krok není potřeba.

## Známé problémy

- **hyprpaper nenačte tapetu z `hyprpaper.conf` automaticky.** Po startu `hyprpaper.service` se v logu objeví `Monitor DP-2 has no target: no wp will be created`, i když `preload`/`wallpaper` řádky v configu jsou správně (ověřeno i s absolutní cestou bez `~`). Zatím nevyřešeno — jde o samostatný, od tohoto deploymentu nezávislý bug (viz `journalctl --user -u hyprpaper.service`). Dočasný obchvat: po startu ručně `hyprctl hyprpaper wallpaper "DP-2,<cesta k obrázku>"`.
