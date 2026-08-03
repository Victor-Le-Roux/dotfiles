#!/usr/bin/env bash

if ! command -v gcalcli >/dev/null 2>&1; then
  echo '{"text":"CAL N/A","class":"muted","tooltip":"Installe et configure gcalcli pour afficher Google Agenda."}'
  exit 0
fi

start_date=$(date +%Y-%m-%d)
end_date=$(date -d "+30 days" +%Y-%m-%d)

agenda_lines=$(LC_ALL=C timeout 20s gcalcli --nocolor agenda "${start_date}" "${end_date}" 2>/dev/null | \
  awk '/^[A-Za-z]{3} [A-Za-z]{3} [ 0-9]{1,2}[[:space:]]+[0-9]{2}:[0-9]{2}/ {print}')

if [ -z "${agenda_lines}" ]; then
  echo '{"text":"","class":"hidden","tooltip":"Aucun rendez-vous dans les 30 prochains jours."}'
  exit 0
fi

now_epoch=$(date +%s)
year=$(date +%Y)
selected_line=""
selected_epoch=""

# Keep "maintenant" only briefly, then switch to the next event.
now_window=90

while IFS= read -r candidate; do
  [ -z "${candidate}" ] && continue

  month=$(printf '%s' "${candidate}" | awk '{print $2}')
  day=$(printf '%s' "${candidate}" | awk '{print $3}')
  time_part=$(printf '%s' "${candidate}" | awk '{print $4}')

  start_raw="${month} ${day} ${year} ${time_part}"
  candidate_epoch=$(date -d "${start_raw}" +%s 2>/dev/null)

  # Handle year rollover when within +30 days across Dec -> Jan.
  if [ -n "${candidate_epoch}" ] && [ "${candidate_epoch}" -lt $((now_epoch - 2592000)) ]; then
    start_raw="${month} ${day} $((year + 1)) ${time_part}"
    candidate_epoch=$(date -d "${start_raw}" +%s 2>/dev/null)
  fi

  [ -z "${candidate_epoch}" ] && continue

  if [ "${candidate_epoch}" -ge $((now_epoch - now_window)) ]; then
    selected_line="${candidate}"
    selected_epoch="${candidate_epoch}"
    break
  fi
done <<< "${agenda_lines}"

if [ -z "${selected_line}" ] || [ -z "${selected_epoch}" ]; then
  echo '{"text":"","class":"hidden","tooltip":"Aucun rendez-vous a venir dans les 30 prochains jours."}'
  exit 0
fi

time_exact=$(date -d "@${selected_epoch}" "+%H:%M" 2>/dev/null)
start_fmt=$(date -d "@${selected_epoch}" "+%d/%m %H:%M" 2>/dev/null)
title_raw=$(printf '%s' "${selected_line}" | cut -d' ' -f5-)
title_clean=$(printf '%s' "${title_raw}" | tr -d '\\"' | sed 's/[[:space:]]\+/ /g' | sed 's/^ //;s/ $//')
title_clean=$(printf '%s' "${title_clean}" | sed -E 's/^[0-9]{2}:[0-9]{2}[[:space:]]+//')
short_title=$(printf '%s' "${title_clean}" | cut -c1-36)
[ -z "${short_title}" ] && short_title="Rendez-vous"

if [ -z "${time_exact}" ]; then
  time_exact=$(printf '%s' "${selected_line}" | awk '{print $4}')
fi
if [ -z "${start_fmt}" ]; then
  start_fmt="${time_exact}"
fi

diff=$((selected_epoch - now_epoch))
rel="bientot"

if [ "${diff}" -ge "-${now_window}" ] && [ "${diff}" -le "${now_window}" ]; then
  rel="maintenant"
elif [ "${diff}" -lt 3600 ]; then
  mins=$(((diff + 59) / 60))
  [ "${mins}" -lt 1 ] && mins=1
  rel="${mins}m"
elif [ "${diff}" -lt 86400 ]; then
  hours=$((diff / 3600))
  mins=$(((diff % 3600) / 60))
  if [ "${mins}" -gt 0 ]; then
    rel="${hours}h${mins}m"
  else
    rel="${hours}h"
  fi
else
  days=$((diff / 86400))
  hours=$(((diff % 86400) / 3600))
  if [ "${hours}" -gt 0 ]; then
    rel="${days}j${hours}h"
  else
    rel="${days}j"
  fi
fi

text="${rel} - ${time_exact}, ${short_title}"
tooltip="Prochain rendez-vous: ${start_fmt} - ${title_clean}"

jq -cn --arg text "${text}" --arg tooltip "${tooltip}" \
  '{text: $text, tooltip: $tooltip}'
