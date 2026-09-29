#!/bin/sh
# The SessionStart hook speaks only when no credential is in place.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT INT TERM
hook="$root/scripts/session-start"

out=$(HOME="$home" STARZERO_API_KEY= "$hook")
case "$out" in
  *"/starzero:setup"*) ;;
  *) printf 'FAIL empty HOME: expected the setup line, got: %s\n' "$out"; exit 1 ;;
esac

mkdir -p "$home/.starzero" && printf '{}\n' > "$home/.starzero/credentials"
out=$(HOME="$home" STARZERO_API_KEY= "$hook")
[ -z "$out" ] || { printf 'FAIL credentials file present: expected silence, got: %s\n' "$out"; exit 1; }

out=$(HOME="$home/none" STARZERO_API_KEY=key "$hook")
[ -z "$out" ] || { printf 'FAIL STARZERO_API_KEY set: expected silence, got: %s\n' "$out"; exit 1; }

mkdir -p "$home/cfg" && printf '{}\n' > "$home/cfg/credentials"
out=$(HOME="$home/none" STARZERO_API_KEY= STARZERO_CONFIG_DIR="$home/cfg" "$hook")
[ -z "$out" ] || { printf 'FAIL STARZERO_CONFIG_DIR credentials: expected silence, got: %s\n' "$out"; exit 1; }

printf 'ok   session-start speaks only without a credential\n'
