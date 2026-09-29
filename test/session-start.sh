#!/bin/sh
# The SessionStart hook speaks only when no credential is in place, and writes the PATH line
# to the env file when Claude Code provides one.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT INT TERM
hook="$root/scripts/session-start"

out=$(HOME="$home" STARZERO_API_KEY='' "$hook")
case "$out" in
  *"/starzero:setup"*) ;;
  *) printf 'FAIL empty HOME: expected the setup line, got: %s\n' "$out"; exit 1 ;;
esac

mkdir -p "$home/.starzero" && printf '{}\n' > "$home/.starzero/credentials"
out=$(HOME="$home" STARZERO_API_KEY='' "$hook")
[ -z "$out" ] || { printf 'FAIL credentials file present: expected silence, got: %s\n' "$out"; exit 1; }

out=$(HOME="$home/none" STARZERO_API_KEY=key "$hook")
[ -z "$out" ] || { printf 'FAIL STARZERO_API_KEY set: expected silence, got: %s\n' "$out"; exit 1; }

mkdir -p "$home/cfg" && printf '{}\n' > "$home/cfg/credentials"
out=$(HOME="$home/none" STARZERO_API_KEY='' STARZERO_CONFIG_DIR="$home/cfg" "$hook")
[ -z "$out" ] || { printf 'FAIL STARZERO_CONFIG_DIR credentials: expected silence, got: %s\n' "$out"; exit 1; }

env_file="$home/env"
out=$(HOME="$home/none" STARZERO_API_KEY=key CLAUDE_ENV_FILE="$env_file" "$hook")
[ -z "$out" ] || { printf 'FAIL with CLAUDE_ENV_FILE: expected silence, got: %s\n' "$out"; exit 1; }
grep -q "^export PATH=\"$root/scripts:\$PATH\"$" "$env_file" || { printf 'FAIL env file lacks the PATH line:\n'; cat "$env_file"; exit 1; }

printf 'ok   session-start speaks only without a credential, and puts scripts/ on PATH\n'
