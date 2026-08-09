# Source adresář se předává explicitně, ať nezáleží na XDG_DATA_HOME. Snap aplikace
# (třeba VSCode) ho přepisují na svůj sandbox a chezmoi pak hledá source jinde —
# v integrovaném terminálu by recepty padaly na "no such file or directory".
chezmoi := "chezmoi --source=" + justfile_directory()

default:
    @just --list

# Nasadit dotfiles (první spuštění nebo po změnách)
apply:
    {{ chezmoi }} apply

# Zobrazit co by se změnilo před nasazením
diff:
    {{ chezmoi }} diff

# Aktuální stav nasazených souborů
status:
    {{ chezmoi }} status

# Povolit a spustit systemd user services
enable-services:
    systemctl --user daemon-reload
    systemctl --user enable --now waybar.service hyprpaper.service mako.service keepassxc.service hyprpolkitagent.service playerctld.service hypr-hud.service

# Zakázat systemd user services
disable-services:
    systemctl --user disable --now waybar.service hyprpaper.service mako.service keepassxc.service hyprpolkitagent.service playerctld.service hypr-hud.service

# Reload Hyprland konfigurace (bez restartu)
reload:
    hyprctl reload

# Restartovat panel
restart-waybar:
    systemctl --user restart waybar.service

# Restartovat notifikační démon (po změně dot_config/mako/config)
restart-mako:
    systemctl --user restart mako.service

# Restartovat tapetu (po změně dot_config/hypr/hyprpaper.conf)
restart-hyprpaper:
    systemctl --user restart hyprpaper.service

# Restartovat KeePassXC (databáze se pak musí znovu odemknout)
restart-keepassxc:
    systemctl --user restart keepassxc.service

# Restartovat control center (po změně QML v dot_config/quickshell/hypr-hud)
restart-hud:
    systemctl --user restart hypr-hud.service

# Otevřít/zavřít control center (test bez klávesové zkratky)
hud:
    ~/.local/bin/hypr-hud toggle

# Zavřít control center (záchranná brzda, kdyby držel klávesnici)
hud-close:
    ~/.local/bin/hypr-hud close

# Vypsat registrované IPC cíle a funkce (kontrola po změně shell.qml)
hud-ipc:
    ~/.local/bin/hypr-hud show

# Spustit control center na popředí s logy (dvě instance by si přebily IPC cíl)
hud-debug:
    systemctl --user stop hypr-hud.service
    ~/.local/bin/hypr-hud run

# Přepnout na openssh agenta místo gcr (kvůli SSH klíčům z KeePassXC)
enable-keyring-integration:
    # Není to chezmoi, je to stav stroje — proto samostatný recept, ať to jde zopakovat.
    systemctl --user mask --now gcr-ssh-agent.socket gcr-ssh-agent.service
    systemctl --user enable --now ssh-agent.socket
    systemctl --user daemon-reload
    @echo "Hotovo. Odhlásit a přihlásit, pak ověřit: echo \$SSH_AUTH_SOCK"

# Vrátit zpět na gcr-ssh-agent (rollback fáze SSH agenta)
disable-keyring-integration:
    systemctl --user disable --now ssh-agent.socket
    systemctl --user unmask gcr-ssh-agent.socket gcr-ssh-agent.service
    systemctl --user daemon-reload

# Vyzkoušet zobrazení notifikací (low / normal / critical)
test-notify:
    notify-send -u low "Nízká priorita" "Zmizí za 3 sekundy"
    notify-send -u normal "Normální priorita" "Zmizí za 5 sekund"
    notify-send -u critical "Kritická priorita" "Zůstane, dokud ji nezavřeš"

# Otevřít přepínač audio výstupů (test bez klávesové zkratky)
audio:
    ~/.local/bin/hypr-audio-menu output

# Screenshot výřezu myší (test bez klávesové zkratky)
screenshot:
    ~/.local/bin/hypr-screenshot region save

# Screenshot výřezu rovnou do anotačního editoru satty
screenshot-edit:
    ~/.local/bin/hypr-screenshot region edit

# Otevřít adresář se screenshoty
screenshots:
    xdg-open "$(xdg-user-dir PICTURES)/Screenshots"

# Restartovat playerctld (bez něj modul "mpris" ve waybaru nevidí metadata)
restart-playerctld:
    systemctl --user restart playerctld.service

# Co waybar modul "mpris" právě vidí (diagnostika metadat)
players:
    @~/.nix-profile/bin/playerctl --list-all || echo "žádný MPRIS přehrávač"
    @~/.nix-profile/bin/playerctl -p playerctld metadata || true

# Vyvolat okno aktivního přehrávače (test pravého kliku ve waybaru)
player-raise:
    ~/.local/bin/hypr-player raise

# První nasazení na nový stroj: apply + enable
bootstrap: apply enable-services enable-keyring-integration
    @echo "Bootstrap dokončen."
