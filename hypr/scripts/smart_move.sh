#!/usr/bin/env bash
# args: l, r, u, d
DIR=$1

if [ -z "$DIR" ]; then
    exit 1
fi

# Get original window
WINDOW=$(hyprctl activewindow -j)
if [ -z "$WINDOW" ] || [ "$WINDOW" == "{}" ]; then
    exit 0
fi

ADDR=$(echo "$WINDOW" | jq -r '.address')
MON=$(echo "$WINDOW" | jq -r '.monitor')

# Move focus
hyprctl dispatch movefocus "$DIR"
NEW_WINDOW=$(hyprctl activewindow -j)
NEW_ADDR=$(echo "$NEW_WINDOW" | jq -r '.address')
NEW_MON=$(echo "$NEW_WINDOW" | jq -r '.monitor')

# If focus didn't change (e.g., edge of the screen)
if [ "$ADDR" == "$NEW_ADDR" ]; then
    hyprctl dispatch movewindow "$DIR"
    exit 0
fi

# Restore focus to original window
hyprctl dispatch focuswindow address:"$ADDR"

if [ "$MON" != "$NEW_MON" ]; then
    # Crossed monitor boundary: use movewindow to send it to the other monitor side-by-side
    hyprctl dispatch movewindow "$DIR"
else
    # Same monitor: use swapwindow to swap places without changing split orientation
    hyprctl dispatch swapwindow "$DIR"
fi
