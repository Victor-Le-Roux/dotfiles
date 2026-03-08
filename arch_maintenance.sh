#!/usr/bin/env bash
set -euo pipefail

# Arch Linux Maintenance Script
# Requires: pacman, sudo
# Optional: paru, flatpak, reflector, paccache (pacman-contrib)

# --- Config ---
LOG_DIR="${HOME}/.local/share/arch-maintenance"
BACKUP_DIR="${HOME}/.local/share/arch-maintenance/backups"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$HOME/backup_config/save-config.sh}"

# --- Options ---
OPT_UPDATE=true
OPT_CACHE_CLEAN=true
OPT_ORPHANS=true
OPT_JOURNALS=true
OPT_BACKUP=true
OPT_FLATPAK=true
OPT_FLATPAK_REINSTALL=false
OPT_MIRRORS=true
OPT_TRIM=true
OPT_CONFIRM=true
OPT_DRY_RUN=false
OPT_AC_REQUIRED=false

# --- Couleurs ---
if [[ -t 1 ]]; then
  GRN=$'\033[0;32m' YEL=$'\033[1;33m' BLU=$'\033[0;34m'
  RED=$'\033[0;31m' PUR=$'\033[0;35m' CYN=$'\033[0;36m'
  BLD=$'\033[1m'    RST=$'\033[0m'
else
  GRN='' YEL='' BLU='' RED='' PUR='' CYN='' BLD='' RST=''
fi

# --- Logging ---
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/maintenance_$(date +%Y-%m-%d_%H%M).log"
exec > >(tee -a "$LOGFILE") 2>&1

# --- Utils ---
have() { command -v "$1" &>/dev/null; }
is_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }

die() { echo -e "${RED}$1${RST}"; exit 1; }

SUDO=()
if ! is_root; then SUDO=(sudo); fi

section() {
  echo ""
  echo -e "${PUR}${BLD}── $1 ${RST}"
}

run() {
  echo -e "${YEL}\$ $*${RST}"
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "${CYN}(dry run)${RST}"
    return 0
  fi
  "$@"
}

confirm() {
  [[ $OPT_CONFIRM == false ]] && return 0
  [[ $OPT_DRY_RUN == true ]] && return 0
  local response
  read -r -p "$(echo -e "${YEL}$1 [y/N] ${RST}")" response || response=""
  [[ ${response,,} =~ ^(y|yes)$ ]]
}

# --- Sudo keep-alive (un seul) ---
KEEPALIVE_PID=""
cleanup() {
  [[ -n $KEEPALIVE_PID ]] && kill "$KEEPALIVE_PID" 2>/dev/null || true
  echo -e "\n${CYN}Log: ${LOGFILE}${RST}"
}
trap cleanup EXIT

start_sudo() {
  [[ $OPT_DRY_RUN == true ]] && return
  have sudo || return
  if ! is_root; then
    sudo -v || die "Impossible d'obtenir sudo."
    ( while sudo -n true 2>/dev/null; do sleep 55; done ) &
    KEEPALIVE_PID=$!
  fi
}

# --- paru wrapper ---
paru_safe() {
  have paru || return 127
  if is_root; then
    [[ -n ${SUDO_USER:-} ]] || die "paru en root sans SUDO_USER."
    runuser -u "$SUDO_USER" -- paru --sudoloop "$@"
  else
    paru --sudoloop "$@"
  fi
}

# --- CLI ---
show_help() {
  cat <<EOF
${BLU}${BLD}arch-maintenance${RST} — Maintenance Arch Linux

${BLD}Usage:${RST} arch-maintenance [options]

${BLD}Options:${RST}
  -h, --help              Affiche cette aide
  -y, --yes               Pas de confirmations
  -d, --dry-run           Affiche sans executer
  -n, --no-update         Skip mise a jour systeme
  -c, --no-cache-clean    Skip nettoyage cache
  -o, --no-orphans        Skip suppression orphelins
  -j, --no-journal-clean  Skip nettoyage journaux
  -b, --no-backup         Skip backup base pacman
  -f, --no-flatpak        Skip flatpak
  -m, --no-mirrors        Skip reflector
  -t, --no-trim           Skip fstrim
  --allow-on-battery      Ne pas exiger le secteur
  --flatpak-reinstall     Reinstaller les flatpaks
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)              show_help ;;
    -y|--yes)               OPT_CONFIRM=false ;;
    -d|--dry-run)           OPT_DRY_RUN=true ;;
    -n|--no-update)         OPT_UPDATE=false ;;
    -c|--no-cache-clean)    OPT_CACHE_CLEAN=false ;;
    -o|--no-orphans)        OPT_ORPHANS=false ;;
    -j|--no-journal-clean)  OPT_JOURNALS=false ;;
    -b|--no-backup)         OPT_BACKUP=false ;;
    -f|--no-flatpak)        OPT_FLATPAK=false ;;
    -m|--no-mirrors)        OPT_MIRRORS=false ;;
    -t|--no-trim)           OPT_TRIM=false ;;
    --allow-on-battery)     OPT_AC_REQUIRED=false ;;
    --flatpak-reinstall)    OPT_FLATPAK_REINSTALL=true ;;
    *) die "Option inconnue: $1 (voir --help)" ;;
  esac
  shift
done

# ══════════════════════════════════════════════════════════════
#  Preflight
# ══════════════════════════════════════════════════════════════

echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${BLU}${BLD}     ARCH LINUX MAINTENANCE              ${RST}"
echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${CYN}Debut: $(date)${RST}"

section "Pre-vol"

# AC power
if [[ $OPT_AC_REQUIRED == true ]]; then
  ac_online=0
  for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD*; do
    [[ -e "$ac/online" ]] || continue
    read -r v < "$ac/online"
    [[ $v == "1" ]] && ac_online=1
  done
  [[ $ac_online -eq 1 ]] || die "Pas sur secteur (--allow-on-battery pour ignorer)."
fi

# Reseau
has_network() {
  have curl && curl -fsI --max-time 3 https://archlinux.org &>/dev/null && return 0
  have ping && ping -c1 -W2 1.1.1.1 &>/dev/null && return 0
  have getent && getent hosts archlinux.org &>/dev/null && return 0
  return 1
}
has_network || die "Pas de reseau."

# Espace disque
check_space() {
  local mount=$1 need=$2
  local free
  free=$(df -Pm "$mount" 2>/dev/null | awk 'NR==2{print $4}')
  [[ -n $free && $free -ge $need ]] || die "Espace insuffisant sur $mount (${free:-0}MB < ${need}MB)."
}
check_space / 2048
check_space /var 2048

# Verrou pacman
[[ ! -e /var/lib/pacman/db.lck ]] || die "Pacman lock actif (/var/lib/pacman/db.lck)."

echo -e "${GRN}Pre-vol OK${RST}"

# Detection outils
echo ""
have paru    && echo -e "${GRN}paru${RST}"    || echo -e "${YEL}paru absent — AUR ignore${RST}"
have flatpak && echo -e "${GRN}flatpak${RST}" || { echo -e "${YEL}flatpak absent${RST}"; OPT_FLATPAK=false; }

# Sudo
start_sudo

# ══════════════════════════════════════════════════════════════
#  Backup config externe
# ══════════════════════════════════════════════════════════════

if [[ -x "$BACKUP_SCRIPT" ]]; then
  if confirm "Lancer la sauvegarde de config ?"; then
    run "$BACKUP_SCRIPT"
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Backup base pacman
# ══════════════════════════════════════════════════════════════

if [[ $OPT_BACKUP == true ]]; then
  section "Backup pacman"
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="${BACKUP_DIR}/pacman_db_$(date +%Y%m%d).tar.gz"
  run "${SUDO[@]}" tar -czf "$BACKUP_FILE" -C /var/lib/pacman/ local
  # Garder les 5 derniers backups
  ls -1t "$BACKUP_DIR"/pacman_db_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
  echo -e "${CYN}Backup: ${BACKUP_FILE}${RST}"
fi

# ══════════════════════════════════════════════════════════════
#  Keyring
# ══════════════════════════════════════════════════════════════

section "Keyring"
# -Sy seul pour le keyring, la maj complete suit immediatement
run "${SUDO[@]}" pacman -Sy --needed --noconfirm archlinux-keyring

# ══════════════════════════════════════════════════════════════
#  Miroirs
# ══════════════════════════════════════════════════════════════

PACMAN_OPTS="-Syu"

if [[ $OPT_MIRRORS == true ]] && have reflector; then
  section "Miroirs"
  if confirm "Actualiser les miroirs ?"; then
    if run "${SUDO[@]}" reflector \
      --country FR,BE,NL,DE,LU,GB \
      --protocol https --age 12 \
      --completion-percent 100 --ipv4 \
      --exclude bjg.at --exclude hadiko.de --exclude soulharsh007.dev \
      --download-timeout 7 --connection-timeout 7 \
      --fastest 15 \
      --save /etc/pacman.d/mirrorlist \
    || run "${SUDO[@]}" reflector \
      --country FR,BE,NL,DE,LU,GB \
      --protocol https --age 12 \
      --completion-percent 100 --ipv4 \
      --exclude bjg.at --exclude hadiko.de --exclude soulharsh007.dev \
      --sort score --number 15 \
      --save /etc/pacman.d/mirrorlist; then
      PACMAN_OPTS="-Syyu"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Mise a jour systeme
# ══════════════════════════════════════════════════════════════

if [[ $OPT_UPDATE == true ]]; then
  section "Mise a jour systeme"
  if confirm "Proceder a la mise a jour ?"; then
    if have paru; then
      run paru_safe $PACMAN_OPTS --noconfirm
    else
      run "${SUDO[@]}" pacman $PACMAN_OPTS --noconfirm
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Sante AUR
# ══════════════════════════════════════════════════════════════

if have paru; then
  section "Sante AUR"
  echo -e "${CYN}MAJ AUR disponibles :${RST}"
  paru -Qua 2>/dev/null || true

  echo -e "${CYN}Paquets AUR out-of-date :${RST}"
  mapfile -t aur_pkgs < <(paru -Qm 2>/dev/null | awk '{print $1}')
  if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
    ood=()
    while IFS= read -r line; do
      case "$line" in
        "Name            : "*) current=${line#"Name            : "} ;;
        *"Out-of-date"*": Yes") [[ -n ${current:-} ]] && ood+=("$current") ;;
      esac
    done < <(paru -Si --aur "${aur_pkgs[@]}" 2>/dev/null || true)
    if [[ ${#ood[@]} -gt 0 ]]; then
      printf '  %s\n' "${ood[@]}"
    else
      echo "Aucun paquet out-of-date."
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Flatpak
# ══════════════════════════════════════════════════════════════

if [[ $OPT_FLATPAK == true ]] && have flatpak; then
  section "Flatpak"
  if confirm "Mettre a jour les Flatpaks ?"; then
    run flatpak update -y
  fi
  if confirm "Nettoyer les runtimes inutilises ?"; then
    run flatpak uninstall --unused -y
  fi

  if [[ $OPT_FLATPAK_REINSTALL == true ]]; then
    if confirm "Reinstaller les Flatpaks ?"; then
      mapfile -t apps < <(flatpak list --app --columns=application)
      if [[ ${#apps[@]} -gt 0 ]]; then
        run flatpak install --reinstall -y "${apps[@]}"
      fi
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Nettoyage cache
# ══════════════════════════════════════════════════════════════

if [[ $OPT_CACHE_CLEAN == true ]]; then
  section "Nettoyage cache paquets"
  if have paccache; then
    run "${SUDO[@]}" paccache -r
    run "${SUDO[@]}" paccache -ruk0
  fi
  if have paru; then
    run paru_safe -Sc --aur --noconfirm
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Orphelins
# ══════════════════════════════════════════════════════════════

if [[ $OPT_ORPHANS == true ]]; then
  section "Orphelins"
  while true; do
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
    if [[ ${#orphans[@]} -eq 0 ]]; then
      echo -e "${GRN}Aucun orphelin (restant)${RST}"
      break
    else
      printf '  %s\n' "${orphans[@]}"
      if confirm "Supprimer ces ${#orphans[@]} orphelins ?"; then
        run "${SUDO[@]}" pacman -Rns --noconfirm "${orphans[@]}"
        [[ $OPT_DRY_RUN == true ]] && break
      else
        break
      fi
    fi
  done
fi

# ══════════════════════════════════════════════════════════════
#  Diagnostics
# ══════════════════════════════════════════════════════════════

section "Services en echec"
systemctl --failed 2>/dev/null || true

section "Logs critiques (priorite 3)"
"${SUDO[@]}" journalctl -p 3 -xb --no-pager -n 20 2>/dev/null || true

# ══════════════════════════════════════════════════════════════
#  TRIM
# ══════════════════════════════════════════════════════════════

if [[ $OPT_TRIM == true ]]; then
  section "TRIM SSD"
  if confirm "Executer fstrim ?"; then
    run "${SUDO[@]}" fstrim -av
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Journaux
# ══════════════════════════════════════════════════════════════

if [[ $OPT_JOURNALS == true ]]; then
  section "Nettoyage journaux"
  if confirm "Supprimer les journaux > 2 semaines ?"; then
    run "${SUDO[@]}" journalctl --vacuum-time=2weeks
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Resume
# ══════════════════════════════════════════════════════════════

section "Disque"
df -h / /var /home 2>/dev/null || df -h

echo ""
echo -e "${BLU}${BLD}══════════════════════════════════════════${RST}"
echo -e "${CYN}Termine: $(date)${RST}"
echo -e "${CYN}Log: ${LOGFILE}${RST}"

skipped=()
[[ $OPT_UPDATE       == false ]] && skipped+=("update")
[[ $OPT_CACHE_CLEAN  == false ]] && skipped+=("cache")
[[ $OPT_ORPHANS      == false ]] && skipped+=("orphelins")
[[ $OPT_JOURNALS     == false ]] && skipped+=("journaux")
[[ $OPT_BACKUP       == false ]] && skipped+=("backup")
[[ $OPT_FLATPAK      == false ]] && skipped+=("flatpak")
[[ $OPT_MIRRORS      == false ]] && skipped+=("miroirs")
[[ $OPT_TRIM         == false ]] && skipped+=("trim")
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo -e "${YEL}Ignore: $(IFS=', '; echo "${skipped[*]}")${RST}"
fi

exit 0
