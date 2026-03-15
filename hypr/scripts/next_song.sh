#!/usr/bin/env bash

YTM_HOST="${YTM_HOST:-127.0.0.1}"
YTM_PORT="${YTM_PORT:-13091}"
CURL_TIMEOUT="${CURL_TIMEOUT:-0.25}"

ytm_next() {
  local base="http://${YTM_HOST}:${YTM_PORT}"

  # Selon versions/plugins, ça peut être /track/next ou /api/track/next
  local urls=(
    "${base}/track/next"
    "${base}/api/track/next"
  )

  for url in "${urls[@]}"; do
    if curl -fsS -m "$CURL_TIMEOUT" -X POST "$url" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

# 1) Spotify (si spotify tourne ET spt existe)
if pgrep -x spotify >/dev/null 2>&1 && command -v spt >/dev/null 2>&1; then
  spt playback --next && exit 0
fi

# 2) YTM via API
if ytm_next; then
  exit 0
fi

# 3) Fallback: playerctl
playerctl next

