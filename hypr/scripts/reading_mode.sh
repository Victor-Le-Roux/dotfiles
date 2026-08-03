#!/usr/bin/env bash
set -euo pipefail

state_dir="$HOME/.cache/hypr/reading-mode"
state_marker="$state_dir/enabled"
shader="$HOME/.config/hypr/shaders/reading_mode.glsl"
base_wallpaper="$HOME/Pictures/wallpapers/kawase_hasui_kawarahata_gunma_1955.jpg"
primary_monitor="DP-2"
aoc_script="$HOME/.config/waybar/scripts/aoc_rotate.sh"

save_gsetting() {
  local schema="$1"
  local key="$2"
  local target="$3"
  gsettings get "$schema" "$key" >"$target" 2>/dev/null || true
}

restore_gsetting() {
  local schema="$1"
  local key="$2"
  local source="$3"
  [[ -s "$source" ]] || return 0
  gsettings set "$schema" "$key" "$(cat "$source")" >/dev/null 2>&1 || true
}

set_wallpaper() {
  local image="$1"
  command -v awww >/dev/null 2>&1 || return 0
  awww query >/dev/null 2>&1 || return 0
  awww img \
    --outputs "$primary_monitor" \
    --resize crop \
    --transition-type none \
    --transition-duration 0 \
    "$image" >/dev/null 2>&1 || true
}

disable_reading_mode() {
  hyprshade off >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true

  restore_gsetting org.gnome.desktop.interface color-scheme "$state_dir/color-scheme"
  restore_gsetting org.gnome.desktop.interface gtk-theme "$state_dir/gtk-theme"
  restore_gsetting org.gnome.desktop.interface icon-theme "$state_dir/icon-theme"

  if [[ -s "$state_dir/brightness" ]]; then
    brightnessctl set "$(cat "$state_dir/brightness")" >/dev/null 2>&1 || true
  fi

  [[ -f "$base_wallpaper" ]] && set_wallpaper "$base_wallpaper"
  [[ -x "$aoc_script" ]] && "$aoc_script" restore >/dev/null 2>&1 || true

  rm -f "$state_marker"
  notify-send "Mode lecture" "Désactivé"
}

enable_reading_mode() {
  mkdir -p "$state_dir"
  save_gsetting org.gnome.desktop.interface color-scheme "$state_dir/color-scheme"
  save_gsetting org.gnome.desktop.interface gtk-theme "$state_dir/gtk-theme"
  save_gsetting org.gnome.desktop.interface icon-theme "$state_dir/icon-theme"
  brightnessctl -m 2>/dev/null | awk -F, 'NR == 1 { print $4 }' >"$state_dir/brightness" || true

  hyprshade on "$shader" >/dev/null
  gsettings set org.gnome.desktop.interface color-scheme "prefer-light" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface gtk-theme "Everforest-Teal-Light" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface icon-theme "Papirus" >/dev/null 2>&1 || true

  hyprctl eval 'hl.config({
    animations = { enabled = false },
    general = {
      gaps_in = 0,
      gaps_out = 0,
      border_size = 2,
      col = {
        active_border = "rgb(000000)",
        inactive_border = "rgb(000000)"
      }
    },
    decoration = {
      rounding = 0,
      dim_inactive = false,
      shadow = { enabled = false },
      blur = { enabled = false }
    }
  })' >/dev/null

  if command -v awww >/dev/null 2>&1 && awww query >/dev/null 2>&1; then
    awww img \
      --outputs "$primary_monitor" \
      --transition-type none \
      --transition-duration 0 \
      0xe8e3d3ff >/dev/null 2>&1 || true
  fi

  brightnessctl set 37% >/dev/null 2>&1 || true
  touch "$state_marker"
  notify-send "Mode lecture" "Activé"
}

if [[ -f "$state_marker" ]]; then
  disable_reading_mode
else
  enable_reading_mode
fi
