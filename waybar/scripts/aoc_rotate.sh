#!/usr/bin/env bash
set -euo pipefail

preferred_monitor="HDMI-A-1"
primary_description="Microstep MAG 272URDF"
monitor_mode="1920x1080@60"
monitor_scale="1"
portrait_wallpaper="$HOME/Pictures/wallpapers/nikko-gaido-the-road-to-nikko.jpg"
landscape_wallpaper="$HOME/Pictures/wallpapers/kawase_hasui_kawarahata_gunma_1955.jpg"
state_dir="$HOME/.config/hypr/state"
state_file="$state_dir/aoc_dp3_transform"
lock_file="/tmp/aoc_rotate_waybar.lock"
action="${1:-status}"

case "$action" in
  status | toggle | restore) ;;
  *) exit 2 ;;
esac

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

if command -v flock >/dev/null 2>&1; then
  exec 9>"$lock_file"
  if [[ "$action" == "status" ]]; then
    flock -n 9 || exit 0
  else
    flock -w 2 9 || exit 1
  fi
fi

monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
[[ -n "$monitors_json" && "$monitors_json" != "[]" ]] || exit 0

monitor_name="$(
  jq -r --arg preferred "$preferred_monitor" '
    (
      [.[] | select((((.make // "") + " " + (.model // "") + " " + (.description // "")) | test("AOC"; "i")))] +
      [.[] | select(.name == $preferred)]
    )[0].name // empty
  ' <<<"$monitors_json"
)"

[[ -n "$monitor_name" ]] || exit 0
[[ "$monitor_name" =~ ^[A-Za-z0-9._-]+$ ]] || exit 1

primary_name="$(
  jq -r --arg description "$primary_description" --arg secondary "$monitor_name" '
    (
      [.[] | select(.description == $description and .name != $secondary)] +
      [.[] | select(.name != $secondary)]
    )[0].name // empty
  ' <<<"$monitors_json"
)"
[[ -n "$primary_name" ]] || exit 1

position="$(
  jq -r --arg primary "$primary_name" '
    .[] |
    select(.name == $primary) |
    (((.x + (.width / .scale)) | floor | tostring) + "x" + (.y | tostring))
  ' <<<"$monitors_json"
)"
[[ "$position" =~ ^-?[0-9]+x-?[0-9]+$ ]] || exit 1

current_transform="$(
  jq -r --arg monitor "$monitor_name" '
    .[] | select(.name == $monitor) | (.transform // 0)
  ' <<<"$monitors_json"
)"
[[ "$current_transform" =~ ^[0-7]$ ]] || current_transform=0

is_portrait() {
  case "$1" in
    1 | 3 | 5 | 7) return 0 ;;
    *) return 1 ;;
  esac
}

wallpaper_for_transform() {
  if is_portrait "$1"; then
    printf '%s\n' "$portrait_wallpaper"
  else
    printf '%s\n' "$landscape_wallpaper"
  fi
}

save_state() {
  local transform="$1"
  mkdir -p "$state_dir"
  printf '%s\n' "$transform" >"$state_file.tmp"
  mv -f "$state_file.tmp" "$state_file"
}

apply_layout() {
  local transform="$1"
  local lua

  lua="hl.monitor({ output = '${monitor_name}', mode = '${monitor_mode}', position = '${position}', scale = ${monitor_scale}, transform = ${transform} })"
  hyprctl eval "$lua" >/dev/null

  for _ in {1..30}; do
    local observed
    observed="$(
      hyprctl -j monitors 2>/dev/null |
        jq -r --arg monitor "$monitor_name" '
          .[] | select(.name == $monitor) | (.transform // 0)
        ' 2>/dev/null || true
    )"
    [[ "$observed" == "$transform" ]] && break
    sleep 0.05
  done
}

apply_wallpaper() {
  local transform="$1"
  local wallpaper

  wallpaper="$(wallpaper_for_transform "$transform")"
  [[ -f "$wallpaper" ]] || return 0
  command -v awww >/dev/null 2>&1 || return 0
  awww query >/dev/null 2>&1 || return 0

  awww img \
    --outputs "$monitor_name" \
    --resize crop \
    --transition-type none \
    --transition-duration 0 \
    "$wallpaper" >/dev/null 2>&1 || true
}

target_transform="$current_transform"
case "$action" in
  toggle)
    if is_portrait "$current_transform"; then
      target_transform=0
    else
      target_transform=1
    fi
    ;;
  restore)
    if [[ -f "$state_file" ]]; then
      saved_transform="$(tr -d '[:space:]' <"$state_file" 2>/dev/null || true)"
      [[ "$saved_transform" =~ ^[0-7]$ ]] && target_transform="$saved_transform"
    fi
    ;;
esac

if [[ "$action" != "status" ]]; then
  apply_layout "$target_transform"
  apply_wallpaper "$target_transform"
  save_state "$target_transform"
  pkill -RTMIN+10 waybar 2>/dev/null || true
fi

if is_portrait "$target_transform"; then
  printf '{"text":"󰍺","tooltip":"AOC (%s) en portrait — clic pour paysage","class":"portrait"}\n' "$monitor_name"
else
  printf '{"text":"󰍹","tooltip":"AOC (%s) en paysage — clic pour portrait","class":"landscape"}\n' "$monitor_name"
fi
