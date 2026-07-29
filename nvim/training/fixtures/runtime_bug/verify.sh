#!/bin/sh

set -eu

actual=$(./runtime_bug -8 -3 -5)
expected='min=-8 max=-3 sum=-16'

if [ "$actual" != "$expected" ]; then
  printf 'Échec\nattendu: %s\nobtenu : %s\n' "$expected" "$actual" >&2
  exit 1
fi

printf 'runtime_bug: OK\n'
