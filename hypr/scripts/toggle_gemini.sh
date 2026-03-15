#!/usr/bin/env bash

# Trouver la fenêtre Gemini
WINDOW=$(hyprctl clients -j | jq -c '.[] | select(.title | test("(?i).*Gemini.*"))' | head -n 1)

if [ -z "$WINDOW" ]; then
    # Si la fenêtre n'existe pas, on ouvre simplement le workspace spécial
    hyprctl dispatch togglespecialworkspace gemini
    exit 0
fi

ADDR=$(echo "$WINDOW" | jq -r '.address')
WS_NAME=$(echo "$WINDOW" | jq -r '.workspace.name')
WS_ID=$(echo "$WINDOW" | jq -r '.workspace.id')

# Vérifier si la fenêtre est actuellement visible à l'écran
if [ "$WS_NAME" == "special:gemini" ]; then
    # Elle est dans le workspace spécial. Est-ce que ce workspace est ouvert sur un écran ?
    IS_VISIBLE=$(hyprctl monitors -j | jq -r '[.[] | .specialWorkspace.name == "special:gemini"] | any')
else
    # Elle est dans un workspace normal. Est-ce que ce workspace est affiché sur un écran ?
    IS_VISIBLE=$(hyprctl monitors -j | jq -r "[.[] | .activeWorkspace.id == $WS_ID] | any")
fi

if [ "$IS_VISIBLE" == "true" ]; then
    # === GEMINI EST VISIBLE -> ON VEUT LE CACHER ===
    
    # 1. S'il n'est pas dans le workspace spécial, on l'y remet silencieusement
    if [ "$WS_NAME" != "special:gemini" ]; then
        hyprctl dispatch movetoworkspacesilent special:gemini,address:$ADDR
    fi
    
    # 2. On vérifie si le workspace spécial est ouvert, et on le ferme
    SPECIAL_OPEN=$(hyprctl monitors -j | jq -r '[.[] | .specialWorkspace.name == "special:gemini"] | any')
    if [ "$SPECIAL_OPEN" == "true" ]; then
        hyprctl dispatch togglespecialworkspace gemini
    fi
else
    # === GEMINI EST CACHÉ -> ON VEUT L'AFFICHER ===
    
    # 1. S'il n'est pas dans le workspace spécial, on l'y remet silencieusement
    if [ "$WS_NAME" != "special:gemini" ]; then
        hyprctl dispatch movetoworkspacesilent special:gemini,address:$ADDR
    fi
    
    # 2. On vérifie si le workspace spécial est fermé, et on l'ouvre
    SPECIAL_OPEN=$(hyprctl monitors -j | jq -r '[.[] | .specialWorkspace.name == "special:gemini"] | any')
    if [ "$SPECIAL_OPEN" == "false" ]; then
        hyprctl dispatch togglespecialworkspace gemini
    fi
    
    # 3. On lui donne le focus
    hyprctl dispatch focuswindow address:$ADDR
fi
