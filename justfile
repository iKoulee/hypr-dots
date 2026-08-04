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
    systemctl --user enable --now waybar.service hyprpaper.service

# Zakázat systemd user services
disable-services:
    systemctl --user disable --now waybar.service hyprpaper.service

# Reload Hyprland konfigurace (bez restartu)
reload:
    hyprctl reload

# Restartovat panel
restart-waybar:
    systemctl --user restart waybar.service

# Otevřít přepínač audio výstupů (test bez klávesové zkratky)
audio:
    ~/.local/bin/hypr-audio-menu output

# První nasazení na nový stroj: apply + enable
bootstrap: apply enable-services
    @echo "Bootstrap dokončen."
