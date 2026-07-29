#!/bin/sh

set -eu

workspace=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
started_at_file=$workspace/.started_at

if [ ! -r "$started_at_file" ]; then
  printf 'Chronomètre introuvable dans %s\n' "$workspace" >&2
  exit 1
fi

started_at=$(sed -n '1p' "$started_at_file")
finished_at=$(date +%s)
elapsed=$((finished_at - started_at))
minutes=$((elapsed / 60))
seconds=$((elapsed % 60))

printf 'Durée : %02d:%02d\n' "$minutes" "$seconds"
printf 'Le workspace reste disponible dans %s\n' "$workspace"
