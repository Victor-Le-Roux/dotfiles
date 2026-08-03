#!/usr/bin/env bash
set -euo pipefail

aoc_script="$HOME/.config/waybar/scripts/aoc_rotate.sh"
preferred_monitor="HDMI-A-1"

[[ -x "$aoc_script" ]] || exit 0

for _ in {1..80}; do
  monitors_json="$(hyprctl -j monitors 2>/dev/null || true)"
  if jq -e --arg preferred "$preferred_monitor" '
    any(.[];
      .name == $preferred or
      (((.make // "") + " " + (.model // "") + " " + (.description // "")) | test("AOC"; "i"))
    )
  ' <<<"$monitors_json" >/dev/null 2>&1; then
    exec "$aoc_script" restore
  fi
  sleep 0.1
done

exit 0
