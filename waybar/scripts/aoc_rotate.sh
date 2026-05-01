#!/usr/bin/env bash
set -euo pipefail

preferred_monitor="HDMI-A-1"
portrait_wallpaper="$HOME/Pictures/wallpapers/nikko-gaido-the-road-to-nikko.jpg"
landscape_wallpaper="$HOME/Pictures/wallpapers/kawase_hasui_kawarahata_gunma_1955.jpg"
monitor_mode="1920x1080@60"
landscape_position="1920x0"
portrait_position="1920x0"
landscape_scale="1"
portrait_scale="1"
lock_file="/tmp/aoc_rotate_waybar.lock"
state_dir="$HOME/.config/hypr/state"
state_file="${state_dir}/aoc_dp3_transform"
action="${1:-status}"

if command -v flock >/dev/null 2>&1; then
  exec 9>"${lock_file}"
  if [[ "${action}" == "toggle" ]]; then
    flock -w 2 9 || exit 1
  else
    flock -n 9 || exit 0
  fi
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 0
fi

monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
if [[ -z "${monitors_json}" || "${monitors_json}" == "[]" ]]; then
  exit 0
fi

monitor_name="$(
  jq -r --arg preferred "${preferred_monitor}" '
    (
      [.[] | select((((.make // "") + " " + (.model // "") + " " + (.description // "")) | test("AOC"; "i")))] +
      [.[] | select(.name == $preferred)]
    )[0].name // empty
  ' <<<"${monitors_json}"
)"

if [[ -z "${monitor_name}" ]]; then
  exit 0
fi

current_transform="$(jq -r --arg mon "${monitor_name}" '.[] | select(.name == $mon) | .transform' <<<"${monitors_json}")"
if [[ -z "${current_transform}" || "${current_transform}" == "null" ]]; then
  current_transform=0
fi

is_portrait=0
case "${current_transform}" in
  1 | 3 | 5 | 7) is_portrait=1 ;;
esac

desired_wallpaper_for_transform() {
  case "${1}" in
    1 | 3 | 5 | 7) printf '%s\n' "${portrait_wallpaper}" ;;
    *) printf '%s\n' "${landscape_wallpaper}" ;;
  esac
}

wallpaper_query() {
  if command -v awww >/dev/null 2>&1; then
    awww query "$@"
  elif command -v swww >/dev/null 2>&1; then
    swww query "$@"
  else
    return 1
  fi
}

wallpaper_img() {
  if command -v awww >/dev/null 2>&1; then
    awww img "$@"
  elif command -v swww >/dev/null 2>&1; then
    swww img "$@"
  else
    return 1
  fi
}

save_transform_state() {
  local value="$1"
  local previous=""
  local tmp_file=""

  [[ "${value}" =~ ^[0-7]$ ]] || return 0
  mkdir -p "${state_dir}"

  if [[ -f "${state_file}" ]]; then
    previous="$(tr -d '[:space:]' <"${state_file}" 2>/dev/null || true)"
    [[ "${previous}" == "${value}" ]] && return 0
  fi

  tmp_file="${state_file}.tmp.$$"
  printf '%s\n' "${value}" >"${tmp_file}"
  mv -f "${tmp_file}" "${state_file}"
}

get_current_wallpaper() {
  wallpaper_query 2>/dev/null | awk -v mon="${monitor_name}" '
    index($0, ": " mon ":") && index($0, "currently displaying: image: ") {
      sub(/^.*currently displaying: image: /, "", $0)
      print
      exit
    }
  '
}

apply_wallpaper() {
  local wanted="$1"
  local current=""

  [[ -f "${wanted}" ]] || return 0
  wallpaper_query >/dev/null 2>&1 || return 0

  current="$(get_current_wallpaper)"
  [[ "${current}" == "${wanted}" ]] && return 0

  for _ in 1 2 3 4 5; do
    wallpaper_img \
      --outputs "${monitor_name}" \
      --resize crop \
      --transition-type none \
      --transition-duration 0 \
      "${wanted}" >/dev/null 2>&1 || true

    sleep 0.12
    current="$(get_current_wallpaper)"
    [[ "${current}" == "${wanted}" ]] && return 0
  done
}

sync_wallpaper_to_transform() {
  local transform="$1"
  local wanted=""
  wanted="$(desired_wallpaper_for_transform "${transform}")"
  apply_wallpaper "${wanted}"
}

wait_for_transform() {
  local target="$1"
  local now=""

  for _ in {1..30}; do
    now="$(hyprctl -j monitors 2>/dev/null | jq -r --arg mon "${monitor_name}" '.[] | select(.name == $mon) | .transform' 2>/dev/null || true)"
    [[ "${now}" == "${target}" ]] && return 0
    sleep 0.05
  done
}

apply_monitor_layout() {
  local target_transform="$1"
  local target_position=""
  local target_scale=""

  case "${target_transform}" in
    1 | 3 | 5 | 7)
      target_position="${portrait_position}"
      target_scale="${portrait_scale}"
      ;;
    *)
      target_position="${landscape_position}"
      target_scale="${landscape_scale}"
      ;;
  esac

  hyprctl keyword monitor "${monitor_name},${monitor_mode},${target_position},${target_scale},transform,${target_transform}" >/dev/null 2>&1
}

print_status() {
  if [[ "${is_portrait}" -eq 1 ]]; then
    printf '{"text":"󰍺","tooltip":"AOC (%s) en portrait - clic pour paysage","class":"portrait"}\n' "${monitor_name}"
  else
    printf '{"text":"󰍹","tooltip":"AOC (%s) en paysage - clic pour portrait","class":"landscape"}\n' "${monitor_name}"
  fi
}

if [[ "${action}" == "toggle" ]]; then
  new_transform=1
  if [[ "${is_portrait}" -eq 1 ]]; then
    new_transform=0
  fi

  apply_monitor_layout "${new_transform}" || exit 1
  wait_for_transform "${new_transform}" || true

  monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
  current_transform="$(jq -r --arg mon "${monitor_name}" '.[] | select(.name == $mon) | .transform' <<<"${monitors_json}")"
  is_portrait=0
  case "${current_transform}" in
    1 | 3 | 5 | 7) is_portrait=1 ;;
  esac

  sync_wallpaper_to_transform "${current_transform}"
  save_transform_state "${current_transform}"
else
  # Self-heal: if transform changed outside this script, keep the right wallpaper.
  sync_wallpaper_to_transform "${current_transform}"
  save_transform_state "${current_transform}"
fi

print_status
