#!/bin/bash

# Récupérer l'état actuel du morceau
current_status=$(spt playback --status)

# Vérifie si "Liked" apparaît dans le statut
if echo "$current_status" | grep -q "♥"; then
  spt playback --dislike
else
  spt playback --like
fi

