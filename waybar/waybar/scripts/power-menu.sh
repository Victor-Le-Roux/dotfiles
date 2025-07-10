#!/bin/bash

entries="Verrouiller l'écran\nSe déconnecter\nSuspendre\nRedémarrer\nÉteindre"

selected=$(echo -e $entries | rofi -dmenu -i -p "Menu d'alimentation")

case $selected in
    "Verrouiller l'écran")
        swaylock;;
    "Se déconnecter")
        hyprctl dispatch exit;;
    "Suspendre")
        systemctl suspend;;
    "Redémarrer")
        systemctl reboot;;
    "Éteindre")
        systemctl poweroff;;
esac
