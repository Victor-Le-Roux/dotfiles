#!/usr/bin/env bash

set -euo pipefail

action="${1:-}"

case "$action" in
  next)
    shortcut_key="right"
    ;;
  prev|previous)
    shortcut_key="left"
    ;;
  *)
    exit 2
    ;;
esac

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

ytm_address="$(
  hyprctl clients -j 2>/dev/null | jq -r '
    map(select(.class == "YouTube Music for Desktop" and .title == "YouTube Music for Desktop"))[0].address // empty
  '
)"

if [[ -z "$ytm_address" ]]; then
  exit 1
fi

hyprctl dispatch sendshortcut "SHIFT_ALT,${shortcut_key},address:${ytm_address}" >/dev/null 2>&1 || exit 1
