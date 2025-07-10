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

# === SECTION GIT ===
echo "Mise à jour du dépôt Git..."

# Aller dans le dossier de backup
cd "$BACKUP_DIR" || exit 1

# Vérifier si c'est un dépôt Git
if [ ! -d ".git" ]; then
    echo "Erreur : $BACKUP_DIR n'est pas un dépôt Git"
    echo "Initialisez-le d'abord avec 'git init' et configurez le remote"
    exit 1
fi

# Ajouter tous les fichiers
git add .

# Vérifier s'il y a des changements
if git diff --cached --quiet; then
    echo "Aucun changement détecté, pas de commit nécessaire"
else
    # Créer le commit avec la date
    COMMIT_MSG="Mise à jour du backup de ma config $(date '+%d/%m/%Y')"
    git commit -m "$COMMIT_MSG"
    
    # Pousser vers GitHub
    echo "Envoi vers GitHub..."
    if git push; then
        echo "✓ Backup envoyé avec succès sur GitHub"
    else
        echo "✗ Erreur lors de l'envoi sur GitHub"
        exit 1
    fi
fi

echo "=== BACKUP TERMINÉ ==="
