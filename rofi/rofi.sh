#!/bin/bash

STATE_FILE="$HOME/.cache/quickshell/theme_mode"

mode="dark"
if [[ -f "$STATE_FILE" ]]; then
  mode="$(<"$STATE_FILE")"
fi

ROFI_MINIMAL="$HOME/.config/rofi/style-minimal.rasi"

rofi -show drun -theme "$ROFI_MINIMAL"
