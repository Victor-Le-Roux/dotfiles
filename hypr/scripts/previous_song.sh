#!/bin/bash

# Vérifie si une session Spotify est ouverte
if pgrep -x "spotify" > /dev/null
then
    # Si Spotify est ouvert, exécute la commande spt
    spt playback --previous
else
    # Sinon, exécute la commande playerctl
    playerctl previous 
fi

