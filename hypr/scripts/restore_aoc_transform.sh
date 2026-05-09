#!/usr/bin/env bash
set -euo pipefail

preferred_monitor="HDMI-A-1"
state_file="$HOME/.config/hypr/state/aoc_dp3_transform"
monitor_mode="1920x1080@60"
landscape_position="3840x0"
portrait_position="3840x0"
landscape_scale="1"
portrait_scale="1"

if ! command -v hyprctl >/dev/null 2>&1; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -f "${state_file}" ]]; then
  exit 0
fi

saved_transform="$(tr -d '[:space:]' <"${state_file}" 2>/dev/null || true)"
if [[ ! "${saved_transform}" =~ ^[0-7]$ ]]; then
  exit 0
fi

detect_monitor() {
  jq -r --arg preferred "${preferred_monitor}" '
    (
      [.[] | select((((.make // "") + " " + (.model // "") + " " + (.description // "")) | test("AOC"; "i")))] +
      [.[] | select(.name == $preferred)]
    )[0].name // empty
  '
}

expected_position_for_transform() {
  case "${1}" in
    1 | 3 | 5 | 7) printf '%s\n' "${portrait_position}" ;;
    *) printf '%s\n' "${landscape_position}" ;;
  esac
}

expected_scale_for_transform() {
  case "${1}" in
    1 | 3 | 5 | 7) printf '%s\n' "${portrait_scale}" ;;
    *) printf '%s\n' "${landscape_scale}" ;;
  esac
}

scale_matches() {
  local current="$1"
  local expected="$2"
  awk -v c="${current}" -v e="${expected}" 'BEGIN { d = c - e; if (d < 0) d = -d; exit(d <= 0.03 ? 0 : 1) }'
}

apply_monitor_layout() {
  local monitor_name="$1"
  local target_transform="$2"
  local target_position=""
  local target_scale=""

  target_position="$(expected_position_for_transform "${target_transform}")"
  target_scale="$(expected_scale_for_transform "${target_transform}")"

  hyprctl keyword monitor "${monitor_name},${monitor_mode},${target_position},${target_scale},transform,${target_transform}" >/dev/null 2>&1 || true
}

for _ in {1..80}; do
  monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
  monitor_name="$(detect_monitor <<<"${monitors_json}")"

  if [[ -n "${monitor_name}" ]]; then
    expected_position="$(expected_position_for_transform "${saved_transform}")"
    expected_scale="$(expected_scale_for_transform "${saved_transform}")"
    expected_x="${expected_position%x*}"
    expected_y="${expected_position#*x}"

    for _ in {1..40}; do
      monitor_json="$(hyprctl -j monitors 2>/dev/null | jq -r --arg mon "${monitor_name}" '.[] | select(.name == $mon)' 2>/dev/null || true)"
      current_transform="$(jq -r '.transform' <<<"${monitor_json}" 2>/dev/null || true)"
      current_x="$(jq -r '.x' <<<"${monitor_json}" 2>/dev/null || true)"
      current_y="$(jq -r '.y' <<<"${monitor_json}" 2>/dev/null || true)"
      current_scale="$(jq -r '.scale' <<<"${monitor_json}" 2>/dev/null || true)"

      if [[ "${current_transform}" == "${saved_transform}" && "${current_x}" == "${expected_x}" && "${current_y}" == "${expected_y}" ]] && scale_matches "${current_scale}" "${expected_scale}"; then
        exit 0
      fi

      apply_monitor_layout "${monitor_name}" "${saved_transform}"
      sleep 0.08
    done
    exit 0
  fi

  sleep 0.1
done

exit 0
