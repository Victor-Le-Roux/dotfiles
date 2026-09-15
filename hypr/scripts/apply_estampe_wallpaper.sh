#!/usr/bin/env bash
set -euo pipefail
# Rendered paper layouts. Original artwork files are never overwritten.
root="$HOME/.config/rice-palette/wallpapers"
wanted="${1:-}"
exec 8>"/tmp/estampe-wallpaper-${UID}.lock"
flock -w 10 8
for _ in {1..50}; do
  if awww query >/dev/null 2>&1; then break; fi
  sleep 0.1
done
awww query >/dev/null
while IFS=$'\t' read -r output width transform description; do
  [[ -z "$wanted" || "$wanted" == "$output" ]] || continue
  case "$transform" in
    1|3|5|7) image="$root/secondary-portrait.png" ;;
    *)
      if [[ "$description" == *'MAG 272URDF'* || "$width" -gt 1920 ]]; then
        image="$root/primary.png"
      else
        image="$root/secondary-landscape.png"
      fi
      ;;
  esac
  awww img --outputs "$output" --resize fit --fill-color e7dfca --transition-type none --transition-duration 0 "$image"
done < <(hyprctl -j monitors | jq -r '.[] | [.name, .width, .transform, .description] | @tsv')
