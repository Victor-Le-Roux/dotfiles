#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"

start_lock() {
  if pgrep -x hyprlock >/dev/null 2>&1; then
    return
  fi

  hyprlock --grace 0 --immediate-render >/dev/null 2>&1 &

  for _ in {1..20}; do
    pgrep -x hyprlock >/dev/null 2>&1 && return
    sleep 0.05
  done

  return 1
}

case "${action}" in
  lock)
    if pgrep -x hyprlock >/dev/null 2>&1; then
      exit 0
    fi
    exec hyprlock --grace 0 --immediate-render
    ;;
  suspend | hibernate)
    start_lock
    exec systemctl "${action}"
    ;;
  *)
    printf 'Usage: %s {lock|suspend|hibernate}\n' "$0" >&2
    exit 2
    ;;
esac
