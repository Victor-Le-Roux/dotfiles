#!/bin/sh

set -eu

CCACHE_DISABLE=1
export CCACHE_DISABLE

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temp_root=$(mktemp -d /tmp/nvim-c-training-test.XXXXXX)
trap 'rm -rf "$temp_root"' EXIT HUP INT TERM

cp -R "$repo_dir/training/fixtures/compile_queue" "$temp_root/"
if make -C "$temp_root/compile_queue" >/dev/null 2>&1; then
  printf 'compile_queue doit commencer en échec\n' >&2
  exit 1
fi

cp -R "$repo_dir/training/fixtures/runtime_bug" "$temp_root/"
make -C "$temp_root/runtime_bug" >/dev/null
if make -C "$temp_root/runtime_bug" test >/dev/null 2>&1; then
  printf 'runtime_bug doit commencer avec un test en échec\n' >&2
  exit 1
fi

cp -R "$repo_dir/training/fixtures/api_change" "$temp_root/"
make -C "$temp_root/api_change" >/dev/null
if make -C "$temp_root/api_change" test >/dev/null 2>&1; then
  printf 'api_change doit exiger la nouvelle API\n' >&2
  exit 1
fi

workspace_output=$("$repo_dir/training/start.sh" runtime_bug)
workspace=$(printf '%s\n' "$workspace_output" | sed -n 's/^Workspace : //p')
case "$workspace" in
  /tmp/nvim-c-training-runtime_bug.*) ;;
  *)
    printf 'workspace inattendu: %s\n' "$workspace" >&2
    exit 1
    ;;
esac
test -r "$workspace/.started_at"
test -x "$workspace/finish.sh"
finish_output=$("$workspace/finish.sh")
printf '%s\n' "$finish_output" | grep -q '^Durée : [0-9][0-9]:[0-9][0-9]$'
rm -rf "$workspace"

printf 'TRAINING_FIXTURES_OK\n'
