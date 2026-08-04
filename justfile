default:
    @just --list

# Nasadit dotfiles (první spuštění nebo po změnách)
apply:
    chezmoi apply

# Zobrazit co by se změnilo před nasazením
diff:
    chezmoi diff

# Aktuální stav nasazených souborů
status:
    chezmoi status

# Povolit a spustit systemd user services
enable-services:
    systemctl --user daemon-reload
    systemctl --user enable --now waybar.service hyprpaper.service mako.service

# Zakázat systemd user services
disable-services:
    systemctl --user disable --now waybar.service hyprpaper.service mako.service

# Reload Hyprland konfigurace (bez restartu)
reload:
    hyprctl reload

# Restartovat panel
restart-waybar:
    systemctl --user restart waybar.service

# Restartovat notifikační démon (po změně dot_config/mako/config)
restart-mako:
    systemctl --user restart mako.service

# Vyzkoušet zobrazení notifikací (low / normal / critical)
test-notify:
    notify-send -u low "Nízká priorita" "Zmizí za 3 sekundy"
    notify-send -u normal "Normální priorita" "Zmizí za 5 sekund"
    notify-send -u critical "Kritická priorita" "Zůstane, dokud ji nezavřeš"

# Otevřít přepínač audio výstupů (test bez klávesové zkratky)
audio:
    ~/.local/bin/hypr-audio-menu output

# První nasazení na nový stroj: apply + enable
bootstrap: apply enable-services
    @echo "Bootstrap dokončen."
