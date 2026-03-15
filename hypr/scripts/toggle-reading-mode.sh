#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.cache/reading_mode_on"

# >>> Mets ici les VRAIS noms présents dans /usr/share/themes
GTK_LIGHT="Everforest-Teal-Light"
GTK_DARK="Everforest-Dark"

ICON_LIGHT="Papirus"
ICON_DARK="Papirus-Dark"   # si tu l’as, sinon garde Papirus

enable() {
  # Shader (nom = basename du .glsl)
  hyprshade on reading_mode || hyprshade on "$HOME/.config/hypr/shaders/reading_mode.glsl"

  # Force light mode (c’est LA clé pour l’effet “papier”)
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' || true
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_LIGHT" || true
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_LIGHT" || true

  # Optionnel : réduire le “bling” pour un look e-ink
  hyprctl keyword decoration:blur:enabled 0
  hyprctl keyword decoration:shadow:enabled 0

  pkill -USR2 waybar 2>/dev/null || true
  mkdir -p "$(dirname "$STATE")"
  : > "$STATE"
}

disable() {
  hyprshade off || true

  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_DARK" || true
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_DARK" || true

  hyprctl keyword decoration:blur:enabled 1
  hyprctl keyword decoration:shadow:enabled 1

  pkill -USR2 waybar 2>/dev/null || true
  rm -f "$STATE"
}

if [[ -f "$STATE" ]]; then
  disable
else
  enable
fi

