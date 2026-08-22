#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

BACKUP_DIR="${BACKUP_DIR:-$HOME/backup_config}"
PKG_LIST_DIR="$BACKUP_DIR/package_liste"
NO_PUSH=${NO_PUSH:-false}

if [[ ! -d $BACKUP_DIR/.git ]]; then
  echo "Erreur : $BACKUP_DIR n'est pas un dépôt Git." >&2
  exit 1
fi

for command in git pacman rsync; do
  command -v "$command" >/dev/null || {
    echo "Erreur : commande absente : $command" >&2
    exit 1
  }
done

mkdir -p "$PKG_LIST_DIR"

sources=(
  "$HOME/.zshrc"
  "$HOME/.config/hypr"
  "$HOME/.config/kitty"
  "$HOME/.config/waybar"
  "$HOME/.config/nvim"
  "$HOME/.config/rofi"
  "$HOME/bin/arch-maintenance"
)
destinations=(
  ".zshrc"
  "hypr"
  "kitty"
  "waybar"
  "nvim"
  "rofi"
  "arch_maintenance.sh"
)

copied=0
missing=0
for index in "${!sources[@]}"; do
  source_path=${sources[$index]}
  destination="$BACKUP_DIR/${destinations[$index]}"

  if [[ -f $source_path ]]; then
    rsync -a --no-owner --no-group -- "$source_path" "$destination"
    ((++copied))
    printf '[OK] %s\n' "$source_path"
  elif [[ -d $source_path ]]; then
    mkdir -p "$destination"
    rsync -a --no-owner --no-group --delete --delete-excluded \
      --exclude='.git/' --exclude='plugged/' --exclude='lazy/' -- \
      "$source_path/" "$destination/"
    ((++copied))
    printf '[OK] %s/\n' "$source_path"
  else
    ((++missing))
    printf '[ABSENT] %s\n' "$source_path" >&2
  fi
done

pacman -Qqe > "$PKG_LIST_DIR/pacman-packages.list"
# Le nom historique est conservé pour les restaurations existantes.
# pacman -Qqem liste les paquets étrangers explicitement installés sans
# dépendre de yay ou de paru.
pacman -Qqem > "$PKG_LIST_DIR/yay-aur-packages.list"

if command -v flatpak >/dev/null; then
  flatpak list --app --columns=application > "$PKG_LIST_DIR/flatpak-apps.list"
else
  : > "$PKG_LIST_DIR/flatpak-apps.list"
fi

git -C "$BACKUP_DIR" add --all
if git -C "$BACKUP_DIR" diff --cached --quiet; then
  echo "Sauvegarde à jour : aucun changement à valider."
else
  git -C "$BACKUP_DIR" commit -m "Mise à jour du backup de configuration $(date '+%d/%m/%Y')"
  if [[ $NO_PUSH == true ]]; then
    echo "Commit local créé ; envoi distant désactivé par NO_PUSH=true."
  else
    git -C "$BACKUP_DIR" push
  fi
fi

printf 'Sauvegarde terminée : %d élément(s), %d absent(s).\n' "$copied" "$missing"
