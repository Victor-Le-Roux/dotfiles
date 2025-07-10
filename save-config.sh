#!/bin/bash

BACKUP_DIR="$HOME/backup_config/"
PKG_LIST_DIR="$BACKUP_DIR/package_liste"
mkdir -p "$BACKUP_DIR"
mkdir -p "$PKG_LIST_DIR"

CONFIGS=(
  "$HOME/.zshrc"
  "$HOME/.config/hypr"
  "$HOME/.config/kitty"
  "$HOME/.config/waybar"
  "$HOME/.config/nvim"
  "$HOME/.config/rofi"
  "$HOME/personal_project/ressources/tools/arch-maintenance/arch_maintenance.sh"
)

TOTAL=${#CONFIGS[@]}
COUNT=0

for ITEM in "${CONFIGS[@]}"; do
  BASENAME=$(basename "$ITEM")
  DEST="$BACKUP_DIR/"
  ((COUNT++))
  PERCENT=$((COUNT * 100 / TOTAL))

  if [ -f "$ITEM" ]; then
    cp "$ITEM" "$DEST"
    STATUS="OK (fichier)"
  elif [ -d "$ITEM" ]; then
    # On utilise rsync pour exclure les dossiers .git
    rsync -a --exclude='.git' "$ITEM" "$DEST"
    STATUS="OK (dossier, .git exclu)"
  else
    STATUS="NON TROUVÉ"
  fi

  echo "[$COUNT/$TOTAL] $BASENAME : $STATUS ($PERCENT%)"
done

# Sauvegarde des listes de paquets
echo "Sauvegarde des listes de paquets dans $PKG_LIST_DIR..."

# Liste des paquets pacman (tous)
pacman -Qqe > "$PKG_LIST_DIR/pacman-packages.list"

# Liste des paquets yay (AUR uniquement)
yay -Qmq > "$PKG_LIST_DIR/yay-aur-packages.list"

# Liste des flatpak
flatpak list --app --columns=application > "$PKG_LIST_DIR/flatpak-apps.list"

echo "Sauvegarde terminée dans $BACKUP_DIR"

