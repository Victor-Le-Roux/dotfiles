#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Maintenance Arch Linux interactive et prudente.
# À lancer en utilisateur normal : les seules opérations privilégiées passent
# explicitement par sudo. Les paquets AUR restent soumis à la revue de paru.

# --- Configuration -----------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-maintenance"
LOG_DIR="${STATE_DIR}/logs"
BACKUP_DIR="${STATE_DIR}/backups"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$HOME/backup_config/save-config.sh}"
PACMAN_CACHE_KEEP="${PACMAN_CACHE_KEEP:-2}"
JOURNAL_RETENTION="${JOURNAL_RETENTION:-4weeks}"

# --- Options -----------------------------------------------------------------
OPT_UPDATE=true
OPT_AUR=true
OPT_CACHE_CLEAN=true
OPT_ORPHANS=true
OPT_JOURNALS=true
OPT_BACKUP=true
OPT_BACKUP_CONFIG=true
OPT_FLATPAK=true
OPT_ZINIT=true
OPT_MIRRORS=false
OPT_TRIM=true
OPT_CONFIRM=true
OPT_AUTO=false
OPT_DRY_RUN=false
OPT_CHECK=false
OPT_AC_REQUIRED=true

# --- Couleurs ----------------------------------------------------------------
if [[ -t 1 ]]; then
  GRN=$'\033[0;32m' YEL=$'\033[1;33m' BLU=$'\033[0;34m'
  RED=$'\033[0;31m' PUR=$'\033[0;35m' CYN=$'\033[0;36m'
  BLD=$'\033[1m' RST=$'\033[0m'
else
  GRN='' YEL='' BLU='' RED='' PUR='' CYN='' BLD='' RST=''
fi

have() { command -v "$1" &>/dev/null; }
is_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }
die() { echo -e "${RED}Erreur : $1${RST}" >&2; exit 1; }

show_help() {
  cat <<EOF
${BLU}${BLD}arch-maintenance${RST} — maintenance Arch Linux

${BLD}Usage :${RST} arch-maintenance [options]

${BLD}Options :${RST}
  -h, --help              Afficher cette aide
  -y, --yes               Tout exécuter sans interaction, y compris l'AUR
  -d, --dry-run           Simuler les commandes (un journal local est créé)
      --check             Audit en lecture seule, adapté au timer utilisateur
  -n, --no-update         Ignorer toutes les mises à jour (dépôts et AUR)
      --no-aur            Ignorer uniquement les mises à jour AUR
      --no-zinit          Ignorer la mise à jour de Zinit et de ses greffons
  -c, --no-cache-clean    Ignorer le nettoyage des caches
  -o, --no-orphans        Ignorer la suppression des orphelins
  -j, --no-journal-clean  Ignorer la rotation des journaux
  -b, --no-backup         Ignorer la sauvegarde de la base pacman
  -B, --no-backup-config  Ignorer la sauvegarde de configuration externe
  -f, --no-flatpak        Ignorer Flatpak
      --mirrors           Forcer Reflector (inutile si reflector.timer est actif)
  -m, --no-mirrors        Ne pas lancer Reflector (comportement par défaut)
  -t, --no-trim           Ne pas lancer fstrim si aucun timer ne le fait
      --allow-on-battery  Autoriser une maintenance hors secteur

${BLD}Attention :${RST} --yes accepte aussi les PKGBUILD AUR sans les afficher.
Lancer ce script sans sudo ; il demandera sudo une seule fois si nécessaire.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)              show_help; exit 0 ;;
    -y|--yes)               OPT_CONFIRM=false; OPT_AUTO=true ;;
    -d|--dry-run)           OPT_DRY_RUN=true ;;
    --check)                OPT_CHECK=true ;;
    -n|--no-update)         OPT_UPDATE=false; OPT_AUR=false; OPT_ZINIT=false ;;
    --no-aur)               OPT_AUR=false ;;
    --no-zinit)             OPT_ZINIT=false ;;
    -c|--no-cache-clean)    OPT_CACHE_CLEAN=false ;;
    -o|--no-orphans)        OPT_ORPHANS=false ;;
    -j|--no-journal-clean)  OPT_JOURNALS=false ;;
    -b|--no-backup)         OPT_BACKUP=false ;;
    -B|--no-backup-config)  OPT_BACKUP_CONFIG=false ;;
    -f|--no-flatpak)        OPT_FLATPAK=false ;;
    --mirrors)              OPT_MIRRORS=true ;;
    -m|--no-mirrors)        OPT_MIRRORS=false ;;
    -t|--no-trim)           OPT_TRIM=false ;;
    --allow-on-battery)     OPT_AC_REQUIRED=false ;;
    --flatpak-reinstall)
      die "--flatpak-reinstall a été retiré : les dépendances Flatpak sont isolées de pacman."
      ;;
    *) die "option inconnue : $1 (voir --help)" ;;
  esac
  shift
done

if [[ $OPT_CHECK == true ]]; then
  OPT_UPDATE=false
  OPT_AUR=false
  OPT_CACHE_CLEAN=false
  OPT_ORPHANS=false
  OPT_JOURNALS=false
  OPT_BACKUP=false
  OPT_BACKUP_CONFIG=false
  OPT_FLATPAK=false
  OPT_ZINIT=false
  OPT_MIRRORS=false
  OPT_TRIM=false
  OPT_CONFIRM=false
  OPT_DRY_RUN=true
fi

is_root && die "lance arch-maintenance en utilisateur normal, sans sudo."

for required in pacman df findmnt flock tee; do
  have "$required" || die "commande requise absente : $required"
done

# --- État, verrou et journal --------------------------------------------------
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOCK_FILE="${STATE_DIR}/arch-maintenance.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || die "une autre instance est déjà en cours."

START_TIME=$SECONDS
ACTIONS_DONE=()
LOGFILE="${LOG_DIR}/maintenance_$(date +%Y-%m-%d_%H%M%S)_${BASHPID}.log"
exec > >(tee -a "$LOGFILE") 2>&1

if [[ $OPT_DRY_RUN == false ]]; then
  find "$LOG_DIR" -maxdepth 1 -type f -name 'maintenance_*.log' \
    -mtime +90 -delete 2>/dev/null || true
fi

SUDO=(sudo)
KEEPALIVE_PID=""

section() {
  echo ""
  echo -e "${PUR}${BLD}── $1 ${RST}"
}

run() {
  printf '%s$' "$YEL"
  printf ' %q' "$@"
  printf '%s\n' "$RST"
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "${CYN}(simulation)${RST}"
    return 0
  fi
  "$@"
}

confirm() {
  [[ $OPT_CONFIRM == false || $OPT_DRY_RUN == true ]] && return 0
  [[ -t 0 ]] || return 1
  local response
  read -r -p "$(echo -e "${YEL}$1 [o/N] ${RST}")" response || response=""
  [[ ${response,,} =~ ^(o|oui|y|yes)$ ]]
}

# shellcheck disable=SC2329
cleanup() {
  local status=$?
  if [[ -n $KEEPALIVE_PID ]]; then
    kill "$KEEPALIVE_PID" 2>/dev/null || true
    wait "$KEEPALIVE_PID" 2>/dev/null || true
  fi
  echo -e "\n${CYN}Journal : ${LOGFILE}${RST}"
  return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

start_sudo() {
  [[ $OPT_DRY_RUN == true ]] && return 0
  have sudo || die "sudo est requis pour les actions système."
  sudo -v || die "impossible d'obtenir les privilèges sudo."
  (
    while sudo -n true 2>/dev/null; do
      sleep 55
    done
  ) &
  KEEPALIVE_PID=$!
}

timer_enabled() {
  local unit=$1
  systemctl is-enabled --quiet "$unit" 2>/dev/null ||
    [[ -e "/etc/systemd/system/timers.target.wants/$unit" ]]
}

has_network() {
  if have curl; then
    curl -fsS --max-time 5 -o /dev/null https://archlinux.org/ && return 0
  fi
  have getent && getent hosts archlinux.org &>/dev/null
}

check_space() {
  local mount=$1
  local minimum_mb=$2
  local free_mb
  free_mb=$(df -Pm "$mount" 2>/dev/null | awk 'NR == 2 {print $4}')
  [[ -n $free_mb && $free_mb -ge $minimum_mb ]] ||
    die "espace insuffisant sur $mount (${free_mb:-0} Mio < ${minimum_mb} Mio)."
}

prune_backups() {
  local -a entries=()
  local entry path

  mapfile -d '' -t entries < <(
    find "$BACKUP_DIR" -maxdepth 1 -type f -name 'pacman_db_*.tar.gz' \
      -printf '%T@ %p\0' | sort -zrn
  )
  for entry in "${entries[@]:5}"; do
    path=${entry#* }
    rm -f -- "$path"
  done
}

# --- Pré-vol -----------------------------------------------------------------
echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${BLU}${BLD}        ARCH LINUX MAINTENANCE            ${RST}"
echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${CYN}Début : $(date)${RST}"

section "Pré-vol"

if [[ $OPT_AC_REQUIRED == true && $OPT_CHECK == false ]]; then
  has_battery=false
  for battery in /sys/class/power_supply/BAT*; do
    if [[ -e "$battery/status" ]]; then
      has_battery=true
      break
    fi
  done

  if [[ $has_battery == true ]]; then
    ac_online=0
    for supply in /sys/class/power_supply/AC* /sys/class/power_supply/ADP*; do
      [[ -r "$supply/online" ]] || continue
      read -r value < "$supply/online"
      [[ $value == 1 ]] && ac_online=1
    done
    [[ $ac_online -eq 1 ]] ||
      die "machine hors secteur (--allow-on-battery pour continuer)."
  fi
fi

NETWORK_OK=false
if has_network; then
  NETWORK_OK=true
  echo -e "${GRN}Réseau disponible${RST}"
else
  echo -e "${YEL}Réseau indisponible${RST}"
  if [[ $OPT_CHECK == false && $OPT_DRY_RUN == false ]] &&
    [[ $OPT_UPDATE == true || $OPT_FLATPAK == true ||
      $OPT_ZINIT == true || $OPT_MIRRORS == true ]]; then
    die "les tâches réseau demandées ne peuvent pas être exécutées."
  fi
fi

if [[ $OPT_UPDATE == true ]]; then
  check_space / 2048
  check_space /var 2048
fi

if [[ -e /var/lib/pacman/db.lck ]] &&
  [[ $OPT_UPDATE == true || $OPT_ORPHANS == true ]]; then
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "${YEL}Verrou pacman actuellement présent${RST}"
  else
    die "verrou pacman actif : /var/lib/pacman/db.lck"
  fi
fi

if timer_enabled reflector.timer; then
  echo -e "${GRN}reflector.timer actif : pas de classement manuel par défaut${RST}"
elif have reflector; then
  echo -e "${CYN}Reflector disponible ; utiliser --mirrors si nécessaire${RST}"
fi

if timer_enabled fstrim.timer; then
  echo -e "${GRN}fstrim.timer actif : pas de TRIM manuel${RST}"
fi

NEEDS_SUDO=false
if [[ $OPT_UPDATE == true || $OPT_CACHE_CLEAN == true ||
  $OPT_ORPHANS == true || $OPT_JOURNALS == true ||
  $OPT_MIRRORS == true || $OPT_TRIM == true ]]; then
  NEEDS_SUDO=true
fi
[[ $NEEDS_SUDO == true ]] && start_sudo

# --- État des mises à jour ----------------------------------------------------
section "Mises à jour disponibles"
REPO_UPDATE_COUNT=0
AUR_UPDATE_COUNT=0
AUR_STATUS_KNOWN=false

if [[ $NETWORK_OK == true ]] && have checkupdates; then
  mapfile -t repo_updates < <(checkupdates 2>/dev/null || true)
  REPO_UPDATE_COUNT=${#repo_updates[@]}
  if ((REPO_UPDATE_COUNT > 0)); then
    printf '  %s\n' "${repo_updates[@]}"
  else
    echo -e "${GRN}Dépôts officiels : à jour${RST}"
  fi
else
  echo -e "${YEL}checkupdates indisponible ou hors ligne${RST}"
fi

if [[ $NETWORK_OK == true ]] && have paru; then
  mapfile -t aur_updates < <(paru -Qua 2>/dev/null || true)
  AUR_UPDATE_COUNT=${#aur_updates[@]}
  AUR_STATUS_KNOWN=true
  if ((AUR_UPDATE_COUNT > 0)); then
    echo -e "${CYN}AUR :${RST}"
    printf '  %s\n' "${aur_updates[@]}"
  else
    echo -e "${GRN}AUR : à jour${RST}"
  fi
elif ! have paru; then
  echo -e "${YEL}paru absent : gestion AUR ignorée${RST}"
else
  echo -e "${YEL}AUR : état inconnu hors ligne${RST}"
fi

if [[ $OPT_UPDATE == true && $NETWORK_OK == true ]] && have paru; then
  section "Actualités Arch"
  paru -Pw 2>/dev/null || echo -e "${CYN}Aucune actualité nouvelle détectée.${RST}"
fi

# --- Sauvegardes --------------------------------------------------------------
if [[ $OPT_BACKUP_CONFIG == true ]]; then
  section "Sauvegarde de configuration"
  if [[ -x $BACKUP_SCRIPT ]]; then
    if confirm "Lancer la sauvegarde de configuration ?"; then
      run "$BACKUP_SCRIPT"
      ACTIONS_DONE+=("✓ Configuration externe sauvegardée")
    fi
  else
    echo -e "${YEL}Script absent ou non exécutable : ${BACKUP_SCRIPT}${RST}"
  fi
fi

if [[ $OPT_BACKUP == true ]]; then
  section "Sauvegarde de la base pacman"
  BACKUP_FILE="${BACKUP_DIR}/pacman_db_$(date +%Y%m%d_%H%M%S).tar.gz"
  printf '%s$ tar -czf %q -C /var/lib/pacman local%s\n' \
    "$YEL" "$BACKUP_FILE" "$RST"
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "${CYN}(simulation)${RST}"
  else
    if tar -czf "$BACKUP_FILE" -C /var/lib/pacman local; then
      chmod 600 "$BACKUP_FILE"
      prune_backups
    else
      rm -f -- "$BACKUP_FILE"
      die "échec de la sauvegarde de la base pacman."
    fi
  fi
  ACTIONS_DONE+=("✓ Base pacman sauvegardée")
fi

# --- Miroirs -----------------------------------------------------------------
if [[ $OPT_MIRRORS == true ]]; then
  section "Miroirs"
  if ! have reflector; then
    echo -e "${YEL}reflector absent : tâche ignorée${RST}"
  elif confirm "Actualiser exceptionnellement les miroirs ?"; then
    if run "${SUDO[@]}" reflector \
      --country FR,BE,NL,DE,LU,GB \
      --protocol https --age 24 \
      --completion-percent 95 \
      --sort rate --number 15 \
      --save /etc/pacman.d/mirrorlist ||
      run "${SUDO[@]}" reflector \
        --country FR,BE,NL,DE,LU,GB \
        --protocol https --age 48 \
        --completion-percent 90 \
        --sort score --number 15 \
        --save /etc/pacman.d/mirrorlist; then
      ACTIONS_DONE+=("✓ Miroirs actualisés")
    fi
  fi
fi

# --- Mise à jour officielle, puis AUR ----------------------------------------
REPO_UPDATE_COMPLETED=false
if [[ $OPT_UPDATE == true ]]; then
  section "Mise à jour des dépôts officiels"
  if confirm "Lancer pacman -Syu ?"; then
    if findmnt -rno FSTYPE / 2>/dev/null | grep -qx btrfs &&
      [[ -d /.snapshots ]] && confirm "Créer un snapshot Btrfs en lecture seule ?"; then
      SNAP_NAME="pre-maintenance_$(date +%Y%m%d_%H%M%S)"
      run "${SUDO[@]}" btrfs subvolume snapshot -r / "/.snapshots/${SNAP_NAME}"
      ACTIONS_DONE+=("✓ Snapshot Btrfs : ${SNAP_NAME}")
    fi

    pacman_args=(-Syu)
    [[ $OPT_CONFIRM == false ]] && pacman_args+=(--noconfirm)
    run "${SUDO[@]}" pacman "${pacman_args[@]}"
    REPO_UPDATE_COMPLETED=true
    ACTIONS_DONE+=("✓ Dépôts officiels mis à jour")
  else
    echo -e "${YEL}Mise à jour officielle refusée ; mise à jour AUR bloquée.${RST}"
  fi
fi

if [[ $OPT_AUR == true ]]; then
  section "Mise à jour AUR"
  aur_args=(-Sua --sudoloop)
  if [[ $OPT_AUTO == true ]]; then
    aur_args+=(--noconfirm --skipreview)
  else
    aur_args+=(--review)
  fi

  if ! have paru; then
    echo -e "${YEL}paru absent : tâche ignorée${RST}"
  elif [[ $REPO_UPDATE_COMPLETED != true ]]; then
    echo -e "${YEL}AUR ignoré : la mise à jour officielle n'a pas été validée.${RST}"
  elif [[ $AUR_STATUS_KNOWN != true ]]; then
    echo -e "${YEL}État AUR inconnu ; commande affichée uniquement en simulation.${RST}"
    run paru "${aur_args[@]}"
  elif ((AUR_UPDATE_COUNT == 0)); then
    echo -e "${GRN}Aucune mise à jour AUR${RST}"
  elif confirm "Mettre à jour les paquets AUR ?"; then
    if [[ $OPT_AUTO == true ]]; then
      echo -e "${YEL}Mode automatique : revue des PKGBUILD AUR désactivée.${RST}"
      run paru "${aur_args[@]}"
      ACTIONS_DONE+=("✓ Paquets AUR mis à jour automatiquement")
    else
      run paru "${aur_args[@]}"
      ACTIONS_DONE+=("✓ Paquets AUR mis à jour après revue")
    fi
  fi
fi

# --- Zinit et greffons Zsh ---------------------------------------------------
if [[ $OPT_ZINIT == true ]]; then
  section "Zinit et greffons Zsh"
  ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/zinit}"
  if [[ ! -r $ZINIT_HOME/zinit.zsh ]]; then
    echo -e "${YEL}Zinit absent : tâche ignorée${RST}"
  elif [[ $NETWORK_OK != true ]]; then
    echo -e "${YEL}Zinit ignoré : réseau indisponible${RST}"
  elif confirm "Mettre à jour Zinit et tous ses greffons ?"; then
    # $1 est volontairement développé par le sous-processus Zsh.
    # shellcheck disable=SC2016
    if run env PAGER=cat GIT_PAGER=cat zsh -fc \
      'source "$1"; zinit update --all' \
      zinit-update "$ZINIT_HOME/zinit.zsh"; then
      ACTIONS_DONE+=("✓ Zinit et greffons Zsh mis à jour")
    else
      echo -e "${RED}Échec de la mise à jour Zinit ; la maintenance continue.${RST}"
    fi
  fi
fi

# --- Flatpak -----------------------------------------------------------------
if [[ $OPT_FLATPAK == true ]]; then
  section "Flatpak"
  if ! have flatpak; then
    echo -e "${YEL}flatpak absent : tâche ignorée${RST}"
  else
    flatpak_args=(-y)
    [[ $OPT_AUTO == true ]] && flatpak_args+=(--noninteractive)
    if confirm "Mettre à jour les Flatpaks ?"; then
      run flatpak update "${flatpak_args[@]}"
      ACTIONS_DONE+=("✓ Flatpaks mis à jour")
    fi
    if confirm "Supprimer les runtimes Flatpak inutilisés ?"; then
      run flatpak uninstall --unused "${flatpak_args[@]}"
      ACTIONS_DONE+=("✓ Runtimes Flatpak inutilisés supprimés")
    fi
  fi
fi

# --- Caches ------------------------------------------------------------------
if [[ $OPT_CACHE_CLEAN == true ]]; then
  section "Cache des paquets"
  if have paccache; then
    run "${SUDO[@]}" paccache -rk "$PACMAN_CACHE_KEEP"
    run "${SUDO[@]}" paccache -ruk0
    ACTIONS_DONE+=("✓ Cache pacman nettoyé, ${PACMAN_CACHE_KEEP} versions conservées")
  else
    echo -e "${YEL}paccache absent (paquet pacman-contrib)${RST}"
  fi

  PARU_CLONE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/paru/clone"
  if [[ -d $PARU_CLONE_DIR ]] &&
    confirm "Supprimer les arbres de construction AUR inutilisés depuis 30 jours ?"; then
    run find "$PARU_CLONE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +30 \
      -exec rm -rf -- '{}' +
    ACTIONS_DONE+=("✓ Anciens arbres de construction AUR supprimés")
  fi
fi

# --- Orphelins ---------------------------------------------------------------
if [[ $OPT_ORPHANS == true ]]; then
  section "Paquets orphelins"
  orphans_removed=0
  while true; do
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
    if ((${#orphans[@]} == 0)); then
      echo -e "${GRN}Aucun orphelin${RST}"
      break
    fi

    printf '  %s\n' "${orphans[@]}"
    if confirm "Supprimer ces ${#orphans[@]} orphelins ?"; then
      pacman_remove_args=(-Rns)
      [[ $OPT_CONFIRM == false ]] && pacman_remove_args+=(--noconfirm)
      run "${SUDO[@]}" pacman "${pacman_remove_args[@]}" "${orphans[@]}"
      orphans_removed=$((orphans_removed + ${#orphans[@]}))
      [[ $OPT_DRY_RUN == true ]] && break
    else
      break
    fi
  done
  ((orphans_removed > 0)) &&
    ACTIONS_DONE+=("✓ ${orphans_removed} orphelins supprimés")
fi

# --- Diagnostics --------------------------------------------------------------
section "Fichiers pacnew / pacsave"
if have pacdiff; then
  mapfile -t pacnew_files < <(pacdiff --output 2>/dev/null || true)
else
  mapfile -t pacnew_files < <(
    find /etc -type f \( -name '*.pacnew' -o -name '*.pacsave' \) \
      -print 2>/dev/null
  )
fi
if ((${#pacnew_files[@]} > 0)); then
  echo -e "${YEL}Configurations à examiner :${RST}"
  printf '  %s\n' "${pacnew_files[@]}"
  have pacdiff &&
    echo -e "${CYN}Fusion interactive : sudo DIFFPROG=nvim pacdiff -s${RST}"
else
  echo -e "${GRN}Aucun pacnew/pacsave${RST}"
fi

section "Sécurité des paquets officiels"
if [[ $NETWORK_OK == true ]] && have arch-audit; then
  audit_output=$(arch-audit --upgradable --show-cve 2>&1 || true)
  if [[ -n $audit_output ]]; then
    printf '%s\n' "$audit_output"
  else
    echo -e "${GRN}Aucune vulnérabilité corrigible signalée${RST}"
  fi
else
  echo -e "${YEL}arch-audit indisponible ou hors ligne${RST}"
fi

section "Santé AUR"
if have paru; then
  paru -Ps 2>/dev/null || true
else
  echo -e "${YEL}paru absent${RST}"
fi

section "Cohérence de la base pacman"
pacman -Dk 2>&1 || true

if have checkrebuild; then
  section "Paquets à reconstruire"
  checkrebuild 2>&1 || true
fi

section "Services en échec"
systemctl --failed --no-pager 2>/dev/null || true

section "Erreurs du démarrage courant"
journalctl -p 3 -b --no-pager -n 20 2>/dev/null || true

# --- TRIM et journaux ---------------------------------------------------------
if [[ $OPT_TRIM == true ]]; then
  section "TRIM SSD"
  if timer_enabled fstrim.timer; then
    echo -e "${GRN}Géré par fstrim.timer ; aucun doublon exécuté${RST}"
  elif confirm "Exécuter fstrim sur les systèmes compatibles ?"; then
    run "${SUDO[@]}" fstrim -av
    ACTIONS_DONE+=("✓ TRIM exécuté")
  fi
fi

if [[ $OPT_JOURNALS == true ]]; then
  section "Rotation des journaux"
  if confirm "Supprimer les journaux antérieurs à ${JOURNAL_RETENTION} ?"; then
    run "${SUDO[@]}" journalctl "--vacuum-time=${JOURNAL_RETENTION}"
    ACTIONS_DONE+=("✓ Journaux limités à ${JOURNAL_RETENTION}")
  fi
fi

# --- Redémarrage --------------------------------------------------------------
section "Redémarrage"
CURRENT_KERNEL=$(uname -r)
if [[ ! -d /usr/lib/modules/$CURRENT_KERNEL ]]; then
  echo -e "${RED}${BLD}Le noyau chargé n'est plus installé : redémarrage recommandé.${RST}"
else
  echo -e "${GRN}Le noyau chargé est encore présent.${RST}"
fi

if have needrestart && confirm "Analyser les processus à redémarrer ?"; then
  run "${SUDO[@]}" needrestart -r l || true
fi

# --- Résumé ------------------------------------------------------------------
section "Disque"
df -h /

echo ""
echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${CYN}Terminé : $(date)${RST}"
echo -e "${CYN}Durée : $((SECONDS - START_TIME)) s${RST}"

if ((${#ACTIONS_DONE[@]} > 0)); then
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "\n${GRN}${BLD}Actions simulées :${RST}"
    printf '  (simulé) %s\n' "${ACTIONS_DONE[@]}"
  else
    echo -e "\n${GRN}${BLD}Actions effectuées :${RST}"
    printf '  %s\n' "${ACTIONS_DONE[@]}"
  fi
fi

if [[ $OPT_CHECK == true ]]; then
  echo -e "\n${CYN}Audit terminé : aucune action système n'a été exécutée.${RST}"
fi

exit 0
