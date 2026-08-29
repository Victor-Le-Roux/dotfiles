#!/usr/bin/env bash
set -euo pipefail

signal_number=9
action="${1:-status}"
query_timeout=4
action_timeout=20
audio_sink_uuid="0000110b-0000-1000-8000-00805f9b34fb"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
if [[ ! -d "${runtime_dir}" || ! -w "${runtime_dir}" ]]; then
  runtime_dir="/tmp"
fi

cache_file="${runtime_dir}/waybar-bluetooth-cache-${UID}.json"
lock_file="${runtime_dir}/waybar-bluetooth-lock-${UID}"
declare -a device_macs=()
declare -a device_names=()
declare -a device_connected=()

print_json() {
  local text="$1"
  local tooltip="$2"
  local class="$3"

  jq -cn \
    --arg text "${text}" \
    --arg tooltip "${tooltip}" \
    --arg class "${class}" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

fallback_json() {
  print_json "󰂲 BT" "Bluetooth indisponible" "off"
}

print_cached_or_fallback() {
  if [[ -r "${cache_file}" ]]; then
    cat "${cache_file}"
  else
    fallback_json
  fi
}

cache_output() {
  local output="$1"
  local tmp_file="${cache_file}.tmp.$$"

  printf '%s\n' "${output}" > "${tmp_file}"
  mv -f "${tmp_file}" "${cache_file}"
}

setup_lock() {
  if ! command -v flock >/dev/null 2>&1; then
    return
  fi

  exec 9>"${lock_file}"

  if [[ "${action}" == "toggle" ]]; then
    flock -w 15 9 || exit 1
  else
    flock -n 9 || {
      print_cached_or_fallback
      exit 0
    }
  fi
}

btctl_query() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${query_timeout}s" bluetoothctl "$@" 2>/dev/null || true
  else
    bluetoothctl "$@" 2>/dev/null || true
  fi
}

btctl_action() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${action_timeout}s" bluetoothctl "$@" 2>/dev/null || true
  else
    bluetoothctl "$@" 2>/dev/null || true
  fi
}

notify() {
  local message="${1:-}"

  if command -v notify-send >/dev/null 2>&1 && [[ -n "${message}" ]]; then
    notify-send "Bluetooth" "${message}"
  fi
}

refresh_waybar() {
  if command -v pkill >/dev/null 2>&1; then
    pkill -RTMIN+"${signal_number}" waybar 2>/dev/null || true
  fi
}

controller_available() {
  local controllers=""

  controllers="$(btctl_query list)"
  grep -q '^Controller ' <<<"${controllers}"
}

is_powered() {
  local state=""

  state="$(btctl_query show | awk '/Powered:/ {print $2; exit}')"
  [[ "${state}" == "yes" ]]
}

device_is_connected() {
  local mac="$1"
  local info=""

  info="$(btctl_query info "${mac}")"
  grep -q 'Connected: yes' <<<"${info}"
}

wait_for_power_state() {
  local wanted="$1"
  local current=0

  for _ in {1..12}; do
    current=0
    is_powered && current=1
    [[ "${current}" -eq "${wanted}" ]] && return 0
    sleep 0.4
  done

  return 1
}

wait_for_connection_state() {
  local mac="$1"
  local wanted="$2"
  local current=0

  for _ in {1..20}; do
    current=0
    device_is_connected "${mac}" && current=1
    [[ "${current}" -eq "${wanted}" ]] && return 0
    sleep 0.4
  done

  return 1
}

pactl_query() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${query_timeout}s" pactl "$@" 2>/dev/null || true
  else
    pactl "$@" 2>/dev/null || true
  fi
}

find_bluetooth_sink() {
  local mac="$1"
  local node_fragment="bluez_output.${mac//:/_}"

  pactl_query list short sinks |
    awk -v fragment="${node_fragment}" '$2 ~ fragment { print $2; exit }'
}

find_speaker_sink() {
  local sinks=""
  local sink=""

  sinks="$(pactl_query list short sinks)"
  sink="$(awk '$2 !~ /^bluez_output\./ && $2 ~ /analog-stereo/ { print $2; exit }' <<<"${sinks}")"

  if [[ -z "${sink}" ]]; then
    sink="$(awk '$2 !~ /^bluez_output\./ { print $2; exit }' <<<"${sinks}")"
  fi

  printf '%s\n' "${sink}"
}

wait_for_bluetooth_sink() {
  local mac="$1"
  local sink=""

  for _ in {1..24}; do
    sink="$(find_bluetooth_sink "${mac}")"
    if [[ -n "${sink}" ]]; then
      printf '%s\n' "${sink}"
      return 0
    fi
    sleep 0.25
  done

  return 1
}

move_active_streams() {
  local sink="$1"
  local input_id=""

  while read -r input_id _; do
    [[ "${input_id}" =~ ^[0-9]+$ ]] || continue
    pactl move-sink-input "${input_id}" "${sink}" >/dev/null 2>&1 || true
  done < <(pactl_query list short sink-inputs)
}

activate_audio_sink() {
  local sink="$1"

  [[ -n "${sink}" ]] || return 1
  pactl set-default-sink "${sink}" >/dev/null 2>&1 || return 1
  move_active_streams "${sink}"
}

switch_to_bluetooth_audio() {
  local mac="$1"
  local sink=""

  sink="$(wait_for_bluetooth_sink "${mac}" || true)"
  [[ -n "${sink}" ]] || return 1
  activate_audio_sink "${sink}"
}

switch_to_speakers_audio() {
  local sink=""

  sink="$(find_speaker_sink)"
  [[ -n "${sink}" ]] || return 1
  activate_audio_sink "${sink}"
}

power_on() {
  btctl_action power on >/dev/null
  wait_for_power_state 1
}

load_devices() {
  local paired_output=""
  local line=""
  local mac=""
  local name=""
  local connected=0
  device_macs=()
  device_names=()
  device_connected=()

  paired_output="$(btctl_query devices Paired)"

  while IFS= read -r line; do
    [[ "${line}" =~ ^Device[[:space:]]+([[:xdigit:]:]{17})[[:space:]]+(.+)$ ]] || continue
    mac="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[2]}"
    connected=0
    device_is_connected "${mac}" && connected=1

    device_macs+=("${mac}")
    device_names+=("${name}")
    device_connected+=("${connected}")
  done <<<"${paired_output}"
}

device_count() {
  printf '%s\n' "${#device_macs[@]}"
}

connected_count() {
  local total=0
  local state=0

  for state in "${device_connected[@]}"; do
    [[ "${state}" -eq 1 ]] && total=$((total + 1))
  done

  printf '%s\n' "${total}"
}

truncate_name() {
  local name="$1"
  local limit="${2:-18}"

  if (( ${#name} <= limit )); then
    printf '%s\n' "${name}"
  else
    printf '%s...\n' "${name:0:limit-3}"
  fi
}

build_tooltip() {
  local powered="$1"
  local total="$2"
  local connected="$3"
  local tooltip=""
  local prefix=""

  if [[ "${powered}" -eq 0 ]]; then
    tooltip="Bluetooth eteint"
  else
    tooltip="Bluetooth actif"
  fi

  if (( total == 0 )); then
    tooltip+=$'\n'"Aucun appareil appaire"
    printf '%s\n' "${tooltip}"
    return
  fi

  for i in "${!device_macs[@]}"; do
    prefix="OFF"
    [[ "${device_connected[i]}" -eq 1 ]] && prefix="ON "
    tooltip+=$'\n'"${prefix} ${device_names[i]}"
  done

  if (( total == 1 )); then
    if (( connected == 1 )); then
      tooltip+=$'\n'"Clic: deconnecter ${device_names[0]}"
    else
      tooltip+=$'\n'"Clic: connecter ${device_names[0]}"
    fi
  else
    tooltip+=$'\n'"Clic: choisir un appareil"
  fi

  printf '%s\n' "${tooltip}"
}

status_text() {
  local powered="$1"
  local total="$2"
  local connected="$3"

  if [[ "${powered}" -eq 0 ]]; then
    printf '󰂲 BT\n'
    return
  fi

  if (( total == 0 )); then
    printf '󰂯 BT\n'
    return
  fi

  if (( total == 1 )); then
    if (( connected == 1 )); then
      printf '󰂱 %s\n' "$(truncate_name "${device_names[0]}")"
    else
      printf '󰂯 %s\n' "$(truncate_name "${device_names[0]}")"
    fi
    return
  fi

  if (( connected > 0 )); then
    printf '󰂱 BT %s\n' "${total}"
  else
    printf '󰂯 BT %s\n' "${total}"
  fi
}

status_class() {
  local powered="$1"
  local connected="$2"

  if [[ "${powered}" -eq 0 ]]; then
    printf 'off\n'
  elif (( connected > 0 )); then
    printf 'connected\n'
  else
    printf 'idle\n'
  fi
}

run_menu() {
  local entries="$1"
  local selection=""

  if command -v rofi >/dev/null 2>&1; then
    selection="$(printf '%s\n' "${entries}" | rofi -dmenu -i -p "Bluetooth" 2>/dev/null || true)"
  elif command -v wofi >/dev/null 2>&1; then
    selection="$(printf '%s\n' "${entries}" | wofi --show dmenu --prompt "Bluetooth" 2>/dev/null || true)"
  elif command -v fuzzel >/dev/null 2>&1; then
    selection="$(printf '%s\n' "${entries}" | fuzzel --dmenu --prompt "Bluetooth> " 2>/dev/null || true)"
  elif command -v bemenu >/dev/null 2>&1; then
    selection="$(printf '%s\n' "${entries}" | bemenu -p "Bluetooth" 2>/dev/null || true)"
  fi

  printf '%s\n' "${selection}"
}

select_device() {
  local state=""
  local selection=""
  local entries=()

  for i in "${!device_macs[@]}"; do
    state="deconnecte"
    [[ "${device_connected[i]}" -eq 1 ]] && state="connecte"
    entries+=("${state} | ${device_names[i]} | ${device_macs[i]}")
  done

  selection="$(run_menu "$(printf '%s\n' "${entries[@]}")")"
  [[ -n "${selection}" ]] || return 1
  [[ "${selection}" =~ ([[:xdigit:]:]{17})$ ]] || return 1

  printf '%s\n' "${BASH_REMATCH[1]}"
}

toggle_device() {
  local mac="$1"
  local name="$2"
  local bluetooth_sink=""

  bluetooth_sink="$(find_bluetooth_sink "${mac}")"

  if device_is_connected "${mac}" && [[ -n "${bluetooth_sink}" ]]; then
    if ! switch_to_speakers_audio; then
      notify "Sortie enceintes introuvable"
    fi

    btctl_action disconnect "${mac}" >/dev/null
    if wait_for_connection_state "${mac}" 0; then
      notify "Enceintes actives — ${name} deconnecte"
      return 0
    fi

    notify "Deconnexion inverifiable: ${name}"
    return 1
  fi

  btctl_action trust "${mac}" >/dev/null
  btctl_action connect "${mac}" "${audio_sink_uuid}" >/dev/null
  if wait_for_connection_state "${mac}" 1; then
    if switch_to_bluetooth_audio "${mac}"; then
      notify "Casque actif: ${name}"
      return 0
    fi

    notify "${name} connecte, mais sortie audio introuvable"
    return 1
  fi

  notify "Connexion impossible: ${name}"
  return 1
}

build_status_output() {
  local powered=0
  local total=0
  local connected=0
  local tooltip=""
  local text=""
  local class=""

  if ! controller_available; then
    print_json "󰂲 BT" "Aucun controleur Bluetooth disponible" "off"
    return
  fi

  is_powered && powered=1
  load_devices
  total="$(device_count)"
  connected="$(connected_count)"
  tooltip="$(build_tooltip "${powered}" "${total}" "${connected}")"
  text="$(status_text "${powered}" "${total}" "${connected}")"
  class="$(status_class "${powered}" "${connected}")"

  print_json "${text}" "${tooltip}" "${class}"
}

print_status() {
  local output=""

  output="$(build_status_output)"
  cache_output "${output}"
  printf '%s\n' "${output}"
}

handle_toggle() {
  local total=0
  local selected_mac=""
  local success=1

  if ! controller_available; then
    notify "Aucun controleur Bluetooth disponible"
    print_status >/dev/null
    refresh_waybar
    exit 0
  fi

  if ! is_powered && ! power_on; then
    notify "Impossible d'activer le Bluetooth"
    print_status >/dev/null
    refresh_waybar
    exit 0
  fi

  load_devices
  total="$(device_count)"

  if (( total == 0 )); then
    notify "Aucun appareil Bluetooth appaire"
    print_status >/dev/null
    refresh_waybar
    exit 0
  fi

  if (( total == 1 )); then
    toggle_device "${device_macs[0]}" "${device_names[0]}" || success=0
    print_status >/dev/null
    refresh_waybar
    (( success == 1 )) && exit 0
    exit 1
  fi

  selected_mac="$(select_device || true)"
  [[ -n "${selected_mac}" ]] || exit 0

  for i in "${!device_macs[@]}"; do
    if [[ "${device_macs[i]}" == "${selected_mac}" ]]; then
      toggle_device "${device_macs[i]}" "${device_names[i]}" || success=0
      break
    fi
  done

  print_status >/dev/null
  refresh_waybar
  (( success == 1 )) && exit 0
  exit 1
}

setup_lock

case "${action}" in
  status)
    print_status
    ;;
  toggle)
    handle_toggle
    ;;
  *)
    print_status
    ;;
esac
