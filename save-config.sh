#!/bin/bash

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

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
    STATUS="${GREEN}OK (fichier)${NC}"
  elif [ -d "$ITEM" ]; then
    # On utilise rsync pour exclure les dossiers .git
    rsync -a --exclude='.git' "$ITEM" "$DEST"
    STATUS="${GREEN}OK (dossier, .git exclu)${NC}"
  else
    STATUS="${RED}NON TROUVÉ${NC}"
  fi
  
  echo -e "${CYAN}[$COUNT/$TOTAL]${NC} ${WHITE}$BASENAME${NC} : $STATUS ${YELLOW}($PERCENT%)${NC}"
done

# Sauvegarde des listes de paquets
echo -e "${PURPLE}Sauvegarde des listes de paquets dans $PKG_LIST_DIR...${NC}"

# Liste des paquets pacman (tous)
pacman -Qqe > "$PKG_LIST_DIR/pacman-packages.list"

# Liste des paquets yay (AUR uniquement)
yay -Qmq > "$PKG_LIST_DIR/yay-aur-packages.list"

# Liste des flatpak
flatpak list --app --columns=application > "$PKG_LIST_DIR/flatpak-apps.list"

echo -e "${GREEN}Sauvegarde terminée dans $BACKUP_DIR${NC}"

# === SECTION GIT ===
echo -e "${BLUE}Mise à jour du dépôt Git...${NC}"

cd "$BACKUP_DIR" || exit 1

if [ ! -d ".git" ]; then
    echo -e "${RED}Erreur : $BACKUP_DIR n'est pas un dépôt Git${NC}"
    exit 1
fi

git add .

if git diff --cached --quiet; then
    echo -e "${YELLOW}Aucun changement détecté${NC}"
else
    git commit -m "Mise à jour du backup de ma config $(date '+%d/%m/%Y')"

    # === SSH AUTOMATIQUE POUR PUSH ===
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_ed25519
    git push
    ssh-agent -k > /dev/null
fi


echo -e "${WHITE}=== ${GREEN}BACKUP TERMINÉ${WHITE} ===${NC}"
