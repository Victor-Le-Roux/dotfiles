#!/usr/bin/env bash
#
# Arch Linux Maintenance Script — single sudo prompt version
# ----------------------------------------------------------
# Objectif : n'exiger qu'une seule saisie de mot de passe maximum
# (au début), puis maintenir la session sudo active pendant toute
# l'exécution, y compris lors des opérations `paru`.
#
# ✅ Recommandé : lancer ce script SANS sudo (en tant qu'utilisateur)
#    -> le script demandera le mot de passe une seule fois puis gardera
#       la session sudo vivante (keep-alive) pendant l'exécution.
#
# ✅ Compatible : si vous le lancez avec sudo (EUID=0), le script
#    maintiendra aussi active la session sudo de $SUDO_USER afin
#    d'éviter tout nouveau prompt lors de l'exécution de `paru`.
#
# Notes sécurité :
# - `paru` reste exécuté en utilisateur non-root.
# - Les commandes système exigeant root passent par sudo quand nécessaire.
# - Aucune modification de sudoers n'est requise.
#
# ----------------------------------------------------------
# Rafraîchit le ticket sudo tant que le script tourne (pas de prompt)
sudo -v
( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID"' EXIT

# --- Couleurs ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'    # No Color
BOLD='\033[1m'

# --- Options par défaut (modifiables via CLI) ---
PERFORM_SYSTEM_UPDATE=true
PERFORM_CACHE_CLEAN=true
REMOVE_ORPHANS=true
CLEAN_JOURNALS=true
AUTO_CONFIRM=false
DRY_RUN=false
BACKUP_PACMAN=true
YOLO_MODE=false
UPDATE_FLATPAK=true
REINSTALL_FLATPAK=false
# --- Utilitaires ---
is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }
SUDO_CMD=""
if ! is_root; then SUDO_CMD="sudo"; fi

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Affichage d'entête
title() {
  echo -e "${BLUE}${BOLD}══════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}        ARCH LINUX MAINTENANCE SCRIPT       ${NC}"
  echo -e "${BLUE}${BOLD}══════════════════════════════════════════${NC}"
}

section() {
  echo ""
  echo -e "${PURPLE}🔷 ${BOLD}$1${NC}"
  echo -e "${PURPLE}────────────────────────────────────────────${NC}"
}

confirm() {
  if [ "$AUTO_CONFIRM" = true ] || [ "$YOLO_MODE" = true ] || [ "$DRY_RUN" = true ]; then
	 return 0
  fi
  local prompt="$1 [y/N] "
  read -r -p "$(echo -e ${YELLOW}$prompt${NC})" response || response=""
  [[ "${response,,}" =~ ^(y|yes)$ ]]
}

run_cmd() {
  local cmd="$1"
  echo -e "${YELLOW}$ ${cmd}${NC}"
  if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}(dry run) commande non exécutée${NC}"
    return 0
  fi
  # shellcheck disable=SC2086
  eval "$cmd"
  local rc=$?
  if [ $rc -eq 0 ]; then
    echo -e "${GREEN}✅ Succès${NC}"
  else
    echo -e "${RED}❌ Erreur (code $rc)${NC}"
  fi
  return $rc
}

# --- Keep-alive sudo : garantit une seule saisie max du mot de passe ---
SUDO_KEEPALIVE_PID=""
start_sudo_keepalive() {
  [ "${DRY_RUN:-false}" = true ] && return
  if ! have_cmd sudo; then return; fi

  if ! is_root; then
    # On valide et on maintient la session sudo de l'utilisateur courant
    sudo -v || { echo -e "${RED}Impossible d'obtenir les privilèges sudo.${NC}"; exit 1; }
    ( while true; do sleep 60; sudo -n true || exit; done ) 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
  else
    # Script lancé avec sudo/root : garder vivante la session sudo de SUDO_USER
    if [ -n "${SUDO_USER:-}" ] && id "${SUDO_USER}" >/dev/null 2>&1; then
      sudo -u "$SUDO_USER" -n -v 2>/dev/null || true
      ( while true; do sleep 60; sudo -u "$SUDO_USER" -n true 2>/dev/null || true; done ) &
      SUDO_KEEPALIVE_PID=$!
      trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
    fi
  fi
}

# --- Helper paru : toujours non-root + --sudoloop ---
paru_safe() {
  if ! have_cmd paru; then
    echo -e "${YELLOW}⚠️  paru non installé — bascule sur pacman si possible.${NC}"
    return 127
  fi

  if is_root; then
    if [ -z "${SUDO_USER:-}" ]; then
      echo -e "${RED}Impossible d'exécuter paru en root sans SUDO_USER. Abandon.${NC}"
      return 1
    fi
    # Exécuter paru en tant que SUDO_USER, sans shell intermédiaire
    runuser -u "$SUDO_USER" -- paru --sudoloop "$@"
  else
    # Utilisateur normal
    paru --sudoloop "$@"
  fi
}

# --- Aide ---
show_help() {
  echo -e "${BLUE}${BOLD}Arch Linux Maintenance Script - Options:${NC}"
  cat <<EOF
  -h, --help             Affiche cette aide
  -n, --no-update        Ne pas faire la mise à jour système
  -c, --no-cache-clean   Ne pas nettoyer le cache des paquets
  -o, --no-orphans       Ne pas supprimer les paquets orphelins
  -j, --no-journal-clean Ne pas nettoyer les journaux systemd
  -y, --yes              Confirmer automatiquement toutes les actions
  --yolo                 Mode agressif (équivaut à --yes, sans confirmations)
  -d, --dry-run          Afficher sans exécuter
  -b, --no-backup        Ne pas sauvegarder la base pacman
  -f, --no-flatpak       Désactiver les opérations Flatpak
  --no-flatpak-reinstall Ne pas réinstaller les applis Flatpak après maintenance
EOF
  exit 0
}
# --- Helpers réseau / AC / espace -------------------------------------------

has_network() {
  # OK si on a HTTP vers archlinux.org, sinon ping 1.1.1.1, sinon DNS
  if command -v curl >/dev/null 2>&1; then
    curl -fsI --max-time 3 https://archlinux.org >/dev/null 2>&1 && return 0
  fi
  command -v ping >/dev/null 2>&1 && ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && return 0
  command -v getent >/dev/null 2>&1 && getent hosts archlinux.org >/dev/null 2>&1 && return 0
  return 1
}

on_ac_power_safe() {
  # true si sur secteur, false sinon, neutre si inconnu
  if command -v on_ac_power >/dev/null 2>&1; then
    on_ac_power
    return $?
  fi
  # vérifie /sys si présent
  for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD*; do
    [ -e "$ac/online" ] || continue
    read -r v < "$ac/online"
    [ "$v" = "1" ] && return 0 || return 1
  done
  return 0  # inconnu -> ne bloque pas
}

# --- Pré-vol -----------------------------------------------------------------

preflight() {
  section "Pré-vol 🛫"
  [ "${RUN_PREFLIGHT:-true}" = "true" ] || { echo -e "${YELLOW}Pré-vol désactivé${NC}"; return; }

  # 1) Secteur (si demandé)
  if [ "${REQUIRE_AC_POWER:-true}" = "true" ]; then
    if ! on_ac_power_safe; then
      echo -e "${RED}⚠️  Pas sur secteur. Branche-toi d'abord (ou --allow-on-battery).${NC}"
      exit 1
    fi
  fi

  # 2) Réseau
  if ! has_network; then
    echo -e "${RED}⚠️  Pas d’accès réseau (HTTP/DNS).${NC}"
    exit 1
  fi

  # 3) Espace disque minimal (en MB)
  local root_need="${MIN_FREE_ROOT_MB:-2048}"
  local var_need="${MIN_FREE_VAR_MB:-2048}"
  local root_free var_free
  root_free=$(df -Pm /    | awk 'NR==2{print $4}')
  var_free=$(df -Pm /var 2>/dev/null | awk 'NR==2{print $4}')
  [ -n "$root_free" ] && [ "$root_free" -ge "$root_need" ] \
    || { echo -e "${RED}⚠️  Espace insuffisant sur / (${root_free:-0}MB < ${root_need}MB).${NC}"; exit 1; }
  if [ -n "$var_free" ]; then
    [ "$var_free" -ge "$var_need" ] \
      || { echo -e "${RED}⚠️  Espace insuffisant sur /var (${var_free}MB < ${var_need}MB).${NC}"; exit 1; }
  fi

  # 4) Verrou pacman
  if [ -e /var/lib/pacman/db.lck ]; then
    echo -e "${RED}⚠️  Un autre pacman est actif (/var/lib/pacman/db.lck).${NC}"
    exit 1
  fi

  echo -e "${GREEN}✅ Pré-vol OK${NC}"
}

# --- Keyring / signatures ----------------------------------------------------

keyring_health() {
  section "Keyring 🔑"
  # Toujours s'assurer que archlinux-keyring est à jour avant upgrade
  run_cmd "${SUDO_CMD} pacman -Sy --needed --noconfirm archlinux-keyring"

  # Refresh facultatif (peut être long) :
  # - FORCE_KEY_REFRESH=yes   => force le refresh
  # - FORCE_KEY_REFRESH=no    => saute le refresh
  # - unset/auto              => demande confirmation
  if command -v pacman-key >/dev/null 2>&1; then
    local do_refresh="no"
    case "${FORCE_KEY_REFRESH:-auto}" in
      yes) do_refresh="yes" ;;
      no)  do_refresh="no"  ;;
      *)   confirm "Rafraîchir les clés PGP (peut être long) ?" && do_refresh="yes" ;;
    esac
    if [ "$do_refresh" = "yes" ]; then
      run_cmd "${SUDO_CMD} pacman-key --refresh-keys" || true
    else
      echo -e "${YELLOW}Refresh des clés PGP sauté${NC}"
    fi
  else
    echo -e "${YELLOW}pacman-key non disponible${NC}"
  fi
}
aur_health() {
  section "Santé AUR 🧪"
  if have_cmd paru; then
    echo -e "${CYAN}MAJ AUR disponibles :${NC}"
    if paru -Qua --quiet >/dev/null 2>&1; then
      paru -Qua --quiet || true
    else
      paru -Qum || true
    fi

    echo -e "${CYAN}Paquets AUR installés marqués Out-of-date :${NC}"
    mapfile -t AUR_PKGS < <(paru -Qm | awk '{print $1}')
    if [ "${#AUR_PKGS[@]}" -eq 0 ]; then
      echo "Aucun paquet AUR installé."
      return
    fi
    OOD_LIST=()
    CHUNK=50
    for ((i=0; i<${#AUR_PKGS[@]}; i+=CHUNK)); do
      pkgs=("${AUR_PKGS[@]:i:CHUNK}")
      # On parse le champ "Out-of-date : Yes" dans la sortie de -Si
      current=""
      while IFS= read -r line; do
        case "$line" in
          "Name            : "*)
            current=${line#"Name            : "}
            ;;
          "Out-of-date     : Yes"|"Out-of-date : Yes")
            [ -n "$current" ] && OOD_LIST+=("$current")
            ;;
        esac
      done < <(paru -Si --aur "${pkgs[@]}" 2>/dev/null || true)
    done

    if [ "${#OOD_LIST[@]}" -gt 0 ]; then
      printf '%s\n' "${OOD_LIST[@]}"
    else
      echo "Aucun paquet installé n'est marqué out-of-date sur l'AUR."
    fi
  else
    echo -e "${YELLOW}paru non installé${NC}"
  fi
}



# --- Parsing CLI ---
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) show_help ;;
    -n|--no-update) PERFORM_SYSTEM_UPDATE=false ;;
    -c|--no-cache-clean) PERFORM_CACHE_CLEAN=false ;;
    -o|--no-orphans) REMOVE_ORPHANS=false ;;
    -j|--no-journal-clean) CLEAN_JOURNALS=false ;;
    -y|--yes) AUTO_CONFIRM=true ;;
    --yolo) YOLO_MODE=true; AUTO_CONFIRM=true ;;
    -d|--dry-run) DRY_RUN=true ;;
    -b|--no-backup) BACKUP_PACMAN=false ;;
    -f|--no-flatpak) UPDATE_FLATPAK=false; REINSTALL_FLATPAK=false ;;
    --no-flatpak-reinstall) REINSTALL_FLATPAK=false ;;
    *) echo -e "${RED}Option inconnue: $1${NC}"; show_help ;;
  esac
  shift
	done

# --- Démarrage ---
clear
title
echo -e "${CYAN}🚀 Lancement à $(date)${NC}\n"

# Active le keep-alive sudo (une seule saisie max)
start_sudo_keepalive
preflight
keyring_health

# --- Détection outils ---
if have_cmd paru; then
  echo -e "${GREEN}✓ paru détecté${NC}"
else
  echo -e "${YELLOW}⚠️  paru non détecté — les paquets AUR ne seront pas mis à jour.${NC}"
fi
if have_cmd flatpak; then
  echo -e "${GREEN}✓ flatpak détecté${NC}"
else
  echo -e "${YELLOW}⚠️  flatpak non détecté — opérations Flatpak ignorées.${NC}"
  UPDATE_FLATPAK=false
  REINSTALL_FLATPAK=false
fi

# --- Sauvegarde de configuration (option externe) ---
BACKUP_SCRIPT_DEFAULT="$HOME/backup_config/save-config.sh"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$BACKUP_SCRIPT_DEFAULT}"
if [ -x "$BACKUP_SCRIPT" ]; then
  if confirm "Voulez-vous lancer la sauvegarde maintenant ?"; then
    run_cmd "\"$BACKUP_SCRIPT\""
  else
    echo -e "${YELLOW}⏩ Sauvegarde ignorée${NC}"
  fi
else
  echo -e "${YELLOW}ℹ️  Script de sauvegarde non trouvé (${BACKUP_SCRIPT}). Étape ignorée.${NC}"
fi

# --- Sauvegarde base pacman ---
if [ "$BACKUP_PACMAN" = true ]; then
  section "Sauvegarde base pacman 💾"
  BACKUP_DATE=$(date +%Y%m%d)
  BACKUP_DIR="/var/lib/pacman/backup"
  BACKUP_FILE="$BACKUP_DIR/pacman_database_${BACKUP_DATE}.tar.gz"
  run_cmd "${SUDO_CMD} mkdir -p \"$BACKUP_DIR\""
  run_cmd "${SUDO_CMD} tar -czf \"$BACKUP_FILE\" -C /var/lib/pacman/ local"
  echo -e "${CYAN}ℹ️  Restauration: ${SUDO_CMD:-sudo} tar -xzf \"$BACKUP_FILE\" -C /var/lib/pacman/${NC}"
fi

# --- Mise à jour des miroirs (reflector) ---
MIRROR_BASE="reflector --country FR,BE,NL,DE,LU,GB --protocol https --age 12 --completion-percent 100 --ipv4"
MIRROR_EXC="--exclude bjg.at --exclude hadiko.de --exclude soulharsh007.dev"
REFLECTOR_FAST="$MIRROR_BASE $MIRROR_EXC --download-timeout 7 --connection-timeout 7 --fastest 15 --save /etc/pacman.d/mirrorlist"
REFLECTOR_SAFE="$MIRROR_BASE $MIRROR_EXC --sort score --number 15 --save /etc/pacman.d/mirrorlist"

if have_cmd reflector && confirm "Actualiser la liste des miroirs les plus rapides ?"; then
  run_cmd "${SUDO_CMD} ${REFLECTOR_FAST}" || run_cmd "${SUDO_CMD} ${REFLECTOR_SAFE}"
  run_cmd "${SUDO_CMD} pacman -Syy"
else
  echo -e "${YELLOW}⏩ Miroirs non actualisés${NC}"
fi

# --- Mise à jour système (repo + AUR via paru) ---
if [ "$PERFORM_SYSTEM_UPDATE" = true ]; then
  section "Mise à jour complète du système 📦"
  echo -e "${CYAN}ℹ️ Cette opération mettra à jour tous les paquets${NC}"
  if confirm "Procéder à la mise à jour ?"; then
    if have_cmd paru; then
      run_cmd "paru_safe -Syu --noconfirm"
      echo -e "${CYAN}🎮 Dépôts officiels et AUR à jour${NC}"
    else
      run_cmd "${SUDO_CMD} pacman -Syu --noconfirm"
      echo -e "${YELLOW}⚠️  AUR non mis à jour faute de paru${NC}"
    fi
  else
    echo -e "${YELLOW}⏩ Mise à jour système ignorée${NC}"
  fi
else
  echo -e "${YELLOW}⏩ Mise à jour système désactivée par option${NC}"
fi
aur_health
# --- Flatpak ---
if [ "$UPDATE_FLATPAK" = true ]; then
  section "Mise à jour des applications Flatpak 📱"
  run_cmd "flatpak list --app"
  if confirm "Mettre à jour les applications Flatpak ?"; then
    run_cmd "flatpak update -y"
  else
    echo -e "${YELLOW}⏩ Mises à jour Flatpak ignorées${NC}"
  fi
  if confirm "Nettoyer les runtimes/extensions Flatpak non utilisés ?"; then
    run_cmd "flatpak uninstall --unused -y"
  else
    echo -e "${YELLOW}⏩ Nettoyage Flatpak ignoré${NC}"
  fi
fi

# --- Nettoyage cache paquets ---
if [ "$PERFORM_CACHE_CLEAN" = true ]; then
  section "Nettoyage du cache des paquets 🧹"
  echo -e "${YELLOW}⚠️  Réduit la possibilité de downgrade${NC}"
  if have_cmd paccache; then
    run_cmd "${SUDO_CMD} paccache -r"
    run_cmd "${SUDO_CMD} paccache -ruk0"
  fi
  # Cache paru
  if have_cmd paru; then
    section "Nettoyage du cache paru 🧹"
    run_cmd "paru_safe -Sc --noconfirm"
  fi
else
  echo -e "${YELLOW}⏩ Nettoyage du cache désactivé par option${NC}"
fi

# --- Suppression des paquets orphelins ---
if [ "$REMOVE_ORPHANS" = true ]; then
  section "Suppression des paquets orphelins 🗑️"
  mapfile -t ORPH_ARR < <(pacman -Qtdq 2>/dev/null || true)
  if [ "${#ORPH_ARR[@]}" -eq 0 ]; then
    echo -e "${GREEN}🔍 Aucun paquet orphelin${NC}"
  else
    echo -e "${YELLOW}🔍 Orphelins détectés :${NC}"; printf '%s\n' "${ORPH_ARR[@]}"
    if confirm "Supprimer ces paquets orphelins ?"; then
      if have_cmd paru; then
        paru --sudoloop -Rns --noconfirm "${ORPH_ARR[@]}"
      else
        ${SUDO_CMD:-sudo} pacman -Rns --noconfirm "${ORPH_ARR[@]}"
      fi
      echo -e "${GREEN}♻️  Orphelins supprimés${NC}"
    else
      echo -e "${YELLOW}⏩ Suppression des orphelins ignorée${NC}"
    fi
  fi
else
  echo -e "${YELLOW}⏩ Suppression des orphelins désactivée par option${NC}"
fi


# --- Services systemd en échec ---
section "Services systemd en échec 🔄"
run_cmd "systemctl --failed" || true

# --- Logs critiques ---
section "Logs système (priorité 3) 📋"
run_cmd "${SUDO_CMD} journalctl -p 3 -xb" || true

# --- TRIM SSD ---
section "Optimisation SSD (TRIM) 💿"
if confirm "Exécuter fstrim -av ?"; then
  run_cmd "${SUDO_CMD} fstrim -av"
else
  echo -e "${YELLOW}⏩ TRIM ignoré${NC}"
fi

# --- Journaux systemd ---
if [ "$CLEAN_JOURNALS" = true ]; then
  section "Nettoyage journaux systemd 📚"
  if confirm "Supprimer les journaux > 2 semaines ?"; then
    run_cmd "${SUDO_CMD} journalctl --vacuum-time=2weeks"
  else
    echo -e "${YELLOW}⏩ Nettoyage journaux ignoré${NC}"
  fi
else
  echo -e "${YELLOW}⏩ Nettoyage journaux désactivé par option${NC}"
fi

# --- Espace disque ---
section "Utilisation disque 📊"
run_cmd "df -h" || true

# --- Réinstallation Flatpak si demandé ---
if [ "$REINSTALL_FLATPAK" = true ] && have_cmd flatpak; then
  section "Réinstallation des applis Flatpak 🔄"
  if confirm "Réinstaller les applis Flatpak pour corriger d'éventuels manques de dépendances ?"; then
    FLATPAK_APPS=$(flatpak list --app --columns=application)
    if [ -n "$FLATPAK_APPS" ]; then
      for app in $FLATPAK_APPS; do
        run_cmd "flatpak install --reinstall -y $app"
      done
      echo -e "${GREEN}✅ Réinstallation Flatpak terminée${NC}"
    else
      echo -e "${YELLOW}Aucune application Flatpak trouvée${NC}"
    fi
  else
    echo -e "${YELLOW}⏩ Réinstallation Flatpak ignorée${NC}"
  fi
fi

# --- Récap ---
echo ""
title
echo -e "${CYAN}🏁 Terminé à $(date)${NC}\n"

SKIPPED=""
[ "$PERFORM_SYSTEM_UPDATE" = false ] && SKIPPED+="mise à jour, "
[ "$PERFORM_CACHE_CLEAN" = false ] && SKIPPED+="nettoyage cache, "
[ "$REMOVE_ORPHANS" = false ] && SKIPPED+="orphelins, "
[ "$CLEAN_JOURNALS" = false ] && SKIPPED+="journaux, "
[ "$BACKUP_PACMAN" = false ] && SKIPPED+="backup pacman, "
[ "$UPDATE_FLATPAK" = false ] && SKIPPED+="flatpak maj, "
[ "$REINSTALL_FLATPAK" = false ] && SKIPPED+="flatpak réinstall, "
if [ -n "$SKIPPED" ]; then
  echo -e "${YELLOW}ℹ️  Étapes ignorées : ${SKIPPED%, }${NC}"
fi

echo -e "${CYAN}💡 Astuces :${NC}"
if have_cmd paru; then
  echo -e "${CYAN}  • Vérifier les paquets AUR (dev) :${NC} ${YELLOW}paru -Sua${NC}"
fi
if have_cmd flatpak; then
  echo -e "${CYAN}  • Lister les MAJ Flatpak :${NC} ${YELLOW}flatpak remote-ls --updates${NC}"
  echo -e "${CYAN}  • Infos sur une app Flatpak :${NC} ${YELLOW}flatpak info <application-id>${NC}"
  echo -e "${CYAN}  • Réparer Flatpak si souci :${NC} ${YELLOW}flatpak repair${NC}"
fi

exit 0

