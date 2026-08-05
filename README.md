# hypr-dots

Hyprland dotfiles (Hyprland, Waybar, Wofi, systemd user services) nasazované přes [chezmoi](https://www.chezmoi.io/). Architektura a konvence repa jsou popsané v `CLAUDE.md`.

## Prerekvizity

- Nix (balíčkovací systém) — na tomto stroji je Nix v novém `nix profile` režimu, ne starém `nix-env`
- SSH klíč zaregistrovaný na GitHubu (repo se klonuje/pushuje přes SSH: `git@github.com:iKoulee/hypr-dots.git`)
- PipeWire/WirePlumber včetně `wpctl` a `pw-dump`, plus `jq` — používá je přepínač audio výstupů `~/.local/bin/hypr-audio-menu` (`Super+Shift+A`, nebo `just audio`). Na běžné distribuci jsou to systémové balíčky, čerstvá instalace je ale mít nemusí.
- `notify-send` (balíček `libnotify`) a `jq` — potřebné pro notifikace a indikátor do-not-disturb ve waybaru.
- `xdg-user-dir` (balíček `xdg-user-dirs`) — screenshoty se ukládají do `$(xdg-user-dir PICTURES)/Screenshots`, na lokalizovaném systému tedy `~/Obrázky/Screenshots`.

## Instalace chezmoi + just

```bash
nix profile install nixpkgs#chezmoi nixpkgs#just
```

## Instalace mako (notifikační démon)

```bash
nix profile install nixpkgs#mako
```

Bez něj nemá kam doručovat notifikace žádná aplikace — na D-Bus se nikdo nepřihlásí k `org.freedesktop.Notifications` a `notify-send` skončí bez efektu. Ovládání je popsané v sekci Notifikace v `CLAUDE.md`.

## Instalace screenshot nástrojů

```bash
nix profile install nixpkgs#grim nixpkgs#slurp nixpkgs#satty
```

`grim` dělá samotný snímek, `slurp` výběr myší, `satty` je anotační editor. `wl-copy` (balíček `wl-clipboard`) už je součástí profilu.

Bez nich klávesa `Print` **mlčky** nic neudělá — Hyprland posílá stdout i stderr spuštěného příkazu do `/dev/null`, takže se chyba nikde neobjeví. Ověřit se to dá spuštěním z terminálu (`just screenshot`). Klávesy a chování jsou popsané v sekci Screenshoty v `CLAUDE.md`.

## Instalace KeePassXC a polkit agenta

```bash
nix profile install nixpkgs#keepassxc nixpkgs#hyprpolkitagent
```

**KeePassXC musí být z nixu, ne ze snapu.** Snap confinement mu neumožňuje ani vlastnit
`org.freedesktop.secrets`, ani sáhnout na ssh-agent socket — detaily v sekci Keyring
a hesla v `CLAUDE.md`. Pokud na stroji snap verze je, po ověření nixové ji odstraň
(`snap remove keepassxc`) a config přenes:

```bash
mkdir -p ~/.config/keepassxc
cp ~/snap/keepassxc/*/.config/keepassxc/keepassxc.ini ~/.config/keepassxc/
```

**KeePassXC 2.7 má configy dva.** Ten v `~/.config/keepassxc/` drží přenositelná
nastavení, zatímco stav vázaný na stroj — hlavně `LastDatabases`, tedy seznam naposledy
otevřených databází — je v `~/.cache/keepassxc/keepassxc.ini`. Ze snapu se přenáší jen
ten první, takže po migraci nemá KeePassXC co otevřít a **zobrazí uvítací obrazovku
s nabídkou založit novou databázi**. Není to chyba: stačí databázi jednou otevřít ručně
(Open existing database), stav se zapíše a od té doby ji `OpenPreviousDatabasesOnStartup`
otevírá sám.

### Ruční nastavení v GUI

`~/.config/keepassxc/` je v `.chezmoiignore` (obsahuje privátní KeeShare klíč a stav),
takže tohle chezmoi nenasadí a je potřeba to nacvakat:

- **General** → *Automatically open previously opened databases*, *Minimize window at
  application startup*, *Show tray icon*, *Minimize instead of close*
- **Secret Service Integration** → zapnout, a v databázi vybrat skupinu, která se má
  vystavit (typicky nová skupina „Secret Service"). **Bez vybrané skupiny integrace
  tiše nefunguje** — na D-Bus je, ale nevrací žádnou kolekci.
- **SSH Agent** → *Enable SSH Agent integration*; u jednotlivých entries pak
  Advanced → SSH Agent → *Add key to agent when database is opened*.

## Firefox mimo snap (nutné pro KeePassXC browser integraci)

Snap Firefox nedokáže spustit `~/.nix-profile/bin/keepassxc-proxy` — jeho AppArmor profil
povoluje exec v `$HOME` jen pro cesty nezačínající tečkou a pro `/nix/store` nemá pravidlo
žádné. Dokud je Firefox snap, browser integrace nefunguje, ať je v configu cokoliv.

Přechod na deb verzi z Mozilla repa (vyžaduje root):

```bash
# 1. Mozilla APT repo
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
  | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

# ověření otisku klíče (musí vyjít 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3)
gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc \
  | awk '/pub/{getline; gsub(/ /,""); print}'

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

# 2. Přednost Mozilla balíčku před ubuntím přechodovým (ten jen nainstaluje snap)
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
  | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

sudo apt update && sudo apt install -y firefox
```

Pak přenos profilu a odstranění snapu — **Firefox musí být zavřený**:

```bash
mkdir -p ~/.mozilla/firefox
cp -a ~/snap/firefox/common/.mozilla/firefox/. ~/.mozilla/firefox/
sudo snap remove firefox          # až po ověření, že deb verze profil otevře
```

Nakonec zkontroluj, že native messaging host míří na nix proxy (mělo by už být nastaveno):

```bash
grep path ~/.mozilla/native-messaging-hosts/org.keepassxc.keepassxc_browser.json
# → "path": "/home/<user>/.nix-profile/bin/keepassxc-proxy"
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

3. Povol a nastartuj systemd user services:

   ```bash
   just enable-services
   ```

4. Přepni systém na openssh agenta místo gcr (kvůli SSH klíčům z KeePassXC):

   ```bash
   just enable-keyring-integration
   ```

   **Efekt nastane až po odhlášení a přihlášení.** Zároveň tím přestane fungovat
   automatické načítání klíčů z `~/.ssh`, které dělal gnome-keyring — klíče je potřeba
   buď přidat do KeePassXC databáze, nebo je po přihlášení načíst ručně přes `ssh-add`.
   Rollback: `just disable-keyring-integration`.

## Běžné příkazy

```bash
just diff             # co by se změnilo
just apply            # nasadit změny
just status           # aktuální stav nasazených souborů
just reload            # reload Hyprlandu bez restartu
just restart-waybar    # restart panelu
just restart-keepassxc # restart správce hesel (databáze se pak musí znovu odemknout)
just enable-services   # systemctl --user enable --now všechny session services
just disable-services  # systemctl --user disable --now všechny session services
just enable-keyring-integration   # přepnout na openssh agenta místo gcr
just disable-keyring-integration  # rollback zpět na gcr-ssh-agent
just screenshot         # snímek výřezu myší (test bez klávesové zkratky)
just screenshot-edit    # snímek výřezu rovnou do editoru satty
just screenshots        # otevřít adresář se screenshoty
just bootstrap          # apply + enable-services + enable-keyring-integration
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

- **Screenshot přes portál (prohlížeč, „sdílet obrazovku") nefunguje.** `xdg-desktop-portal-hyprland` je nainstalovaný, ale nikdy nenaběhne — systemd user `XDG_DATA_DIRS` neobsahuje `~/.nix-profile/share`, takže systémový portál jeho `hyprland.portal` nenajde a jede jen `-gtk`, který na wlroots interaktivní screenshot neumí. Klávesa `Print` a `hypr-screenshot` portál obcházejí (grim mluví se screencopy protokolem přímo), takže fungují.

- **hyprpaper nenačte tapetu z `hyprpaper.conf` automaticky.** Po startu `hyprpaper.service` se v logu objeví `Monitor DP-2 has no target: no wp will be created`, i když `preload`/`wallpaper` řádky v configu jsou správně (ověřeno i s absolutní cestou bez `~`). Zatím nevyřešeno — jde o samostatný, od tohoto deploymentu nezávislý bug (viz `journalctl --user -u hyprpaper.service`). Dočasný obchvat: po startu ručně `hyprctl hyprpaper wallpaper "DP-2,<cesta k obrázku>"`.
