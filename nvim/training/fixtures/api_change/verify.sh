#!/bin/sh

set -eu

check_case()
{
  actual=$(./api_change "$1" "$2" "$3")
  if [ "$actual" != "$4" ]; then
    printf 'Échec: ./api_change %s %s %s\n' "$1" "$2" "$3" >&2
    printf 'attendu: %s, obtenu: %s\n' "$4" "$actual" >&2
    exit 1
  fi
}

check_case 2 5 10 5
check_case 7 5 10 7
check_case 15 5 10 10
printf 'api_change: OK\n'
