#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s {compile_queue|runtime_bug|api_change}\n' "$0" >&2
  exit 2
fi

exercise=$1
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
fixture_dir=$script_dir/fixtures/$exercise

if [ ! -d "$fixture_dir" ]; then
  printf 'Exercice inconnu : %s\n' "$exercise" >&2
  exit 2
fi

workspace=$(mktemp -d "/tmp/nvim-c-training-${exercise}.XXXXXX")
cp -R "$fixture_dir/." "$workspace/"
cp "$script_dir/finish.sh" "$workspace/finish.sh"
date +%s > "$workspace/.started_at"
chmod +x "$workspace/finish.sh"

printf 'Benchmark : %s\n' "$exercise"
printf 'Workspace : %s\n' "$workspace"
printf 'Ouvre-le avec : nvim %s\n' "$workspace"
printf 'À la fin : %s/finish.sh\n' "$workspace"
