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
OPT_BACKUP_CONFIG=true
OPT_FLATPAK=true
OPT_FLATPAK_REINSTALL=false
OPT_MIRRORS=true
OPT_TRIM=true
OPT_CONFIRM=true
OPT_DRY_RUN=false
OPT_AC_REQUIRED=true

# --- Couleurs ---
if [[ -t 1 ]]; then
  GRN=$'\033[0;32m' YEL=$'\033[1;33m' BLU=$'\033[0;34m'
  RED=$'\033[0;31m' PUR=$'\033[0;35m' CYN=$'\033[0;36m'
  BLD=$'\033[1m'    RST=$'\033[0m'
else
  GRN='' YEL='' BLU='' RED='' PUR='' CYN='' BLD='' RST=''
fi

START_TIME=$SECONDS
ACTIONS_DONE=()

# --- Logging ---
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/maintenance_$(date +%Y-%m-%d_%H%M).log"
exec > >(tee -a "$LOGFILE") 2>&1
ls -1t "$LOG_DIR"/maintenance_*.log 2>/dev/null | tail -n +11 | xargs -r rm -f

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
  echo -e "${YEL}\$$(printf ' %q' "$@")${RST}"
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
trap cleanup EXIT INT TERM HUP

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
  -B, --no-backup-config  Skip backup config externe
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
    -B|--no-backup-config)  OPT_BACKUP_CONFIG=false ;;
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
  # Sur PC fixe, aucune batterie n'existe → check inutile, on passe
  has_battery=false
  for bat in /sys/class/power_supply/BAT*; do
    [[ -e "$bat/status" ]] && has_battery=true && break
  done

  if [[ $has_battery == true ]]; then
    ac_online=0
    for ac in /sys/class/power_supply/AC* /sys/class/power_supply/ACAD*; do
      [[ -e "$ac/online" ]] || continue
      read -r v < "$ac/online"
      [[ $v == "1" ]] && ac_online=1
    done
    [[ $ac_online -eq 1 ]] || die "Pas sur secteur (--allow-on-battery pour ignorer)."
  else
    echo -e "${CYN}Pas de batterie détectée (PC fixe) — vérification secteur ignorée.${RST}"
  fi
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
if findmnt /var &>/dev/null; then check_space /var 2048; fi

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

if [[ $OPT_BACKUP_CONFIG == true ]] && [[ -x "$BACKUP_SCRIPT" ]]; then
  if confirm "Lancer la sauvegarde de config ?"; then
    run "$BACKUP_SCRIPT"
    ACTIONS_DONE+=("✓ Configuration externe sauvegardée")
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Backup base pacman
# ══════════════════════════════════════════════════════════════

if [[ $OPT_BACKUP == true ]]; then
  section "Backup pacman"
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="${BACKUP_DIR}/pacman_db_$(date +%Y%m%d_%H%M).tar.gz"
  run "${SUDO[@]}" tar -czf "$BACKUP_FILE" -C /var/lib/pacman/ local
  # Garder les 5 derniers backups
  if [[ $OPT_DRY_RUN == false ]]; then
    ls -1t "$BACKUP_DIR"/pacman_db_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
  fi
  echo -e "${CYN}Backup: ${BACKUP_FILE}${RST}"
  ACTIONS_DONE+=("✓ Base pacman sauvegardée")
fi

# ══════════════════════════════════════════════════════════════
#  Keyring
# ══════════════════════════════════════════════════════════════

if [[ $OPT_UPDATE == true ]]; then
  section "Keyring"
  # -S seul pour le keyring, pour eviter une maj partielle en cas de --no-update
  run "${SUDO[@]}" pacman -S --needed --noconfirm archlinux-keyring
  ACTIONS_DONE+=("✓ Keyring mis à jour")
fi

# ══════════════════════════════════════════════════════════════
#  Miroirs
# ══════════════════════════════════════════════════════════════

PACMAN_OPTS=(-Syu)

if [[ $OPT_MIRRORS == true ]] && have reflector; then
  section "Miroirs"
  if confirm "Actualiser les miroirs ?"; then
    if run "${SUDO[@]}" reflector \
      --country FR,BE,NL,DE,LU,GB \
      --protocol https --age 24 \
      --completion-percent 95 \
      --sort rate --number 10 \
      --save /etc/pacman.d/mirrorlist \
    || run "${SUDO[@]}" reflector \
      --country FR,BE,NL,DE,LU,GB \
      --protocol https --age 48 \
      --completion-percent 90 \
      --sort score --number 10 \
      --save /etc/pacman.d/mirrorlist; then
      PACMAN_OPTS=(-Syyu)
      ACTIONS_DONE+=("✓ Miroirs actualisés")
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
      run paru_safe "${PACMAN_OPTS[@]}" --noconfirm
    else
      run "${SUDO[@]}" pacman "${PACMAN_OPTS[@]}" --noconfirm
    fi
    ACTIONS_DONE+=("✓ Système mis à jour")
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Sante AUR
# ══════════════════════════════════════════════════════════════

if have paru; then
  section "Sante AUR"
  echo -e "${CYN}MAJ AUR disponibles :${RST}"
  paru -Qua 2>/dev/null || true

  mapfile -t foreign_pkgs < <(pacman -Qm | awk '{print $1}')
  if [[ ${#foreign_pkgs[@]} -gt 0 ]]; then
    echo -e "${CYN}Analyse des paquets externes (${#foreign_pkgs[@]})...${RST}"
    
    pkgs_encoded=$(printf 'arg[]=%s\n' "${foreign_pkgs[@]}" | paste -sd '&')
    if have python3 && have curl; then
      aur_data=$(curl -s "https://aur.archlinux.org/rpc/v5/info?${pkgs_encoded}" 2>/dev/null || echo "{}")
      
      read -r -d '' py_script << 'EOF' || true
import sys, json
try:
    data = json.load(sys.stdin)
    results = {pkg["Name"]: pkg for pkg in data.get("results", [])}
    foreign_pkgs = sys.argv[1:]
    ood = []
    dropped = []
    for pkg in foreign_pkgs:
        if pkg not in results:
            dropped.append(pkg)
        elif results[pkg].get("OutOfDate"):
            ood.append(pkg)
    
    if ood:
        print("OOD:" + ",".join(ood))
    if dropped:
        print("DRP:" + ",".join(dropped))
except Exception as e:
    print(f"WARN: AUR parse error: {e}", file=sys.stderr)
EOF
      
      parsed=$(echo "$aur_data" | python3 -c "$py_script" "${foreign_pkgs[@]}")
	  if [[ -z "$parsed" && "$aur_data" != "{}" ]]; then
		echo -e "${YEL}⚠️  Analyse AUR incomplète (erreur Python, voir stderr)${RST}"
	  fi
      
      ood=$(echo "$parsed" | grep "^OOD:" | cut -d: -f2)
      dropped=$(echo "$parsed" | grep "^DRP:" | cut -d: -f2)
      
      echo -e "\n${CYN}Paquets AUR out-of-date :${RST}"
      if [[ -n $ood ]]; then
        echo "$ood" | tr ',' '\n' | sed 's/^/  - /'
      else
        echo "  Aucun paquet out-of-date."
      fi
      
      echo -e "\n${CYN}Paquets introuvables sur AUR (Abandonnés ?) :${RST}"
      if [[ -n $dropped ]]; then
        echo -e "${RED}⚠️  Ces paquets sont installés mais introuvables :${RST}"
        echo "$dropped" | tr ',' '\n' | sed 's/^/  - /'
      else
        echo -e "${GRN}  Tous les paquets externes existent encore sur AUR.${RST}"
      fi
    else
      echo -e "${YEL}python3 ou curl manquant, vérification avancée ignorée.${RST}"
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
    ACTIONS_DONE+=("✓ Flatpaks mis à jour")
  fi
  if confirm "Nettoyer les runtimes inutilises ?"; then
    run flatpak uninstall --unused -y
    ACTIONS_DONE+=("✓ Runtimes Flatpak nettoyés")
  fi

  if [[ $OPT_FLATPAK_REINSTALL == true ]]; then
    if confirm "Reinstaller les Flatpaks ?"; then
      mapfile -t apps < <(flatpak list --app --columns=application)
      if [[ ${#apps[@]} -gt 0 ]]; then
        run flatpak install --reinstall -y "${apps[@]}"
        ACTIONS_DONE+=("✓ Flatpaks réinstallés")
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
    ACTIONS_DONE+=("✓ Cache pacman nettoyé")
  fi
  if have paru; then
    if run paru_safe -Sc --aur --noconfirm; then
      ACTIONS_DONE+=("✓ Cache AUR nettoyé")
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Orphelins
# ══════════════════════════════════════════════════════════════

if [[ $OPT_ORPHANS == true ]]; then
  section "Orphelins"
  orphans_removed=0
  while true; do
    mapfile -t orphans < <(pacman -Qtdq 2>/dev/null || true)
    if [[ ${#orphans[@]} -eq 0 ]]; then
      echo -e "${GRN}Aucun orphelin (restant)${RST}"
      break
    else
      printf '  %s\n' "${orphans[@]}"
      if confirm "Supprimer ces ${#orphans[@]} orphelins ?"; then
        run "${SUDO[@]}" pacman -Rns --noconfirm "${orphans[@]}"
        orphans_removed=$((orphans_removed + ${#orphans[@]}))
        [[ $OPT_DRY_RUN == true ]] && break
      else
        break
      fi
    fi
  done
  if [[ $orphans_removed -gt 0 ]]; then
    ACTIONS_DONE+=("✓ $orphans_removed orphelins supprimés")
  fi
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
    ACTIONS_DONE+=("✓ TRIM exécuté")
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Journaux
# ══════════════════════════════════════════════════════════════

if [[ $OPT_JOURNALS == true ]]; then
  section "Nettoyage journaux"
  if confirm "Supprimer les journaux > 2 semaines ?"; then
    run "${SUDO[@]}" journalctl --vacuum-time=2weeks
    ACTIONS_DONE+=("✓ Journaux nettoyés")
  fi
fi

# ══════════════════════════════════════════════════════════════
#  Nécessité de Redémarrage
# ══════════════════════════════════════════════════════════════

section "Vérification des processus / Kernel"
# Vérification si le noyau chargé en RAM est différent de celui sur le disque
CURRENT_KERNEL=$(uname -r)
if [[ ! -d "/usr/lib/modules/${CURRENT_KERNEL}" ]]; then
  echo -e "${RED}${BLD}⚠️  Le noyau a été mis à jour. Un redémarrage est fortement recommandé.${RST}"
else
  echo -e "${GRN}Noyau à jour (aucun redémarrage critique requis).${RST}"
fi


# Optionnel : si vous avez installé 'needrestart'
if have needrestart; then
  if confirm "Vérifier les services nécessitant un redémarrage ?"; then
    run "${SUDO[@]}" needrestart -r l || true
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
echo -e "${CYN}Durée: $((SECONDS - START_TIME))s${RST}"
echo -e "${CYN}Log: ${LOGFILE}${RST}"

if [[ ${#ACTIONS_DONE[@]} -gt 0 ]]; then
  if [[ $OPT_DRY_RUN == true ]]; then
    echo -e "\n${GRN}${BLD}Actions simulées :${RST}"
    printf '  (simulé) %s\n' "${ACTIONS_DONE[@]}"
  else
    echo -e "\n${GRN}${BLD}Actions effectuées :${RST}"
    printf '  %s\n' "${ACTIONS_DONE[@]}"
  fi
fi

skipped=()
[[ $OPT_UPDATE       == false ]] && skipped+=("update")
[[ $OPT_CACHE_CLEAN  == false ]] && skipped+=("cache")
[[ $OPT_ORPHANS      == false ]] && skipped+=("orphelins")
[[ $OPT_JOURNALS     == false ]] && skipped+=("journaux")
[[ $OPT_BACKUP       == false ]] && skipped+=("backup")
[[ $OPT_BACKUP_CONFIG == false ]] && skipped+=("backup-config")
[[ $OPT_FLATPAK      == false ]] && skipped+=("flatpak")
[[ $OPT_MIRRORS      == false ]] && skipped+=("miroirs")
[[ $OPT_TRIM         == false ]] && skipped+=("trim")
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo -e "\n${YEL}Ignore: $(IFS=', '; echo "${skipped[*]}")${RST}"
fi

exit 0
