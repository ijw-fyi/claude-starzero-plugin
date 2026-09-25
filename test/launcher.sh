#!/bin/sh
# Runs the launcher in an empty HOME: it must download the pinned CLI, verify it, and print the
# pinned version. Needs network access to github.com.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
want=$(tr -d '[:space:]' < "$root/reference/CLI_VERSION")
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT INT TERM

got=$(HOME="$home" "$root/scripts/starzero" --version 2>"$home/stderr")
if [ "$got" != "$want" ]; then
  printf 'FAIL launcher printed %s, expected %s\n' "$got" "$want"
  cat "$home/stderr"
  exit 1
fi
grep -q "starzero $want installed" "$home/stderr" || { printf 'FAIL first run did not report an install\n'; cat "$home/stderr"; exit 1; }

got=$(HOME="$home" "$root/scripts/starzero" --version 2>"$home/stderr")
[ -s "$home/stderr" ] && { printf 'FAIL second run wrote to stderr:\n'; cat "$home/stderr"; exit 1; }
[ "$got" = "$want" ] || { printf 'FAIL second run printed %s\n' "$got"; exit 1; }

printf 'ok   launcher installs and runs starzero %s\n' "$want"
