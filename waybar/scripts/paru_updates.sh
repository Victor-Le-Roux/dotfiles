#!/usr/bin/env bash

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
cache_file="${runtime_dir}/waybar-updates-cache-${UID}.json"
stamp_file="${runtime_dir}/waybar-updates-stamp-${UID}"
hidden_output='{"text":"","class":"hidden"}'

print_cached_or_hidden() {
  if [ -r "${cache_file}" ]; then
    cat "${cache_file}"
  else
    echo "${hidden_output}"
  fi
}

if ! command -v paru >/dev/null 2>&1; then
  echo '{"text":"UPD N/A"}'
  exit 0
fi

local_mtime=$(stat -Lc "%Y" /var/lib/pacman/local 2>/dev/null || echo 0)
sync_mtime=$(stat -Lc "%Y" /var/lib/pacman/sync 2>/dev/null || echo 0)
stamp="${local_mtime}:${sync_mtime}"

if [ -f /var/lib/pacman/db.lck ]; then
  print_cached_or_hidden
  exit 0
fi

if [ -r "${stamp_file}" ] && [ -r "${cache_file}" ]; then
  previous_stamp=$(cat "${stamp_file}")
  if [ "${previous_stamp}" = "${stamp}" ]; then
    cat "${cache_file}"
    exit 0
  fi
fi

count=$(paru -Qu 2>/dev/null | wc -l)
count=$(printf '%s' "${count}" | tr -d '[:space:]')
case "${count}" in
  ''|*[!0-9]*) count=0 ;;
esac

if [ "${count}" -eq 0 ]; then
  output="${hidden_output}"
else
  output="{\"text\":\"UPD ${count}\"}"
fi

printf '%s\n' "${output}" > "${cache_file}"
printf '%s\n' "${stamp}" > "${stamp_file}"

echo "${output}"
