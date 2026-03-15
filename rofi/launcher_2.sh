#!/usr/bin/env bash

dir="$HOME/.config/rofi"
theme='style-minimal'

# 1. Run Rofi (no global Hyprland changes)
selected=$(rofi \
    -show drun \
    -theme ${dir}/${theme}.rasi \
    -drun-print-desktop \
    -print-to-stdout \
    2>/dev/null)
    
exit_code=$?

# Case 1: ESC or closed the menu (Exit Code 1)
if [ $exit_code -eq 1 ] || [ -z "$selected" ]; then
    exit 0
fi

# Case 2: App is launched (Exit Code 0)
if [ $exit_code -eq 0 ]; then
    if [[ "$selected" == *.desktop ]]; then
        app_id=$(basename "$selected" .desktop)
        gtk-launch "$app_id" > /dev/null 2>&1 &
    fi
    exit 0
fi

# Case 3: Used a Custom Keybind like Shift+Enter
xdg-open "https://www.google.com/search?q=${selected}" > /dev/null 2>&1 &
