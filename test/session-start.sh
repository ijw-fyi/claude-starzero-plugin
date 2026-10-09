#!/bin/sh
# The SessionStart hook says whether a login is stored (the CLI is the route) or not (setup first),
# names the connector as optional in both cases, and writes the PATH line to the env file when
# Claude Code provides one.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT INT TERM
hook="$root/scripts/session-start"

expect() { # <label> <needle> <output>
  case "$3" in
    *"$2"*) ;;
    *) printf 'FAIL %s: expected "%s" in: %s\n' "$1" "$2" "$3"; exit 1 ;;
  esac
}
lacks() { # <label> <needle> <output>
  case "$3" in
    *"$2"*) printf 'FAIL %s: did not expect "%s" in: %s\n' "$1" "$2" "$3"; exit 1 ;;
  esac
}
one_line() { # <label> <output>
  [ "$(printf '%s\n' "$2" | wc -l)" -eq 1 ] || { printf 'FAIL %s: expected one line, got: %s\n' "$1" "$2"; exit 1; }
}

out=$(HOME="$home" STARZERO_API_KEY='' "$hook")
expect "empty HOME" "/starzero:setup" "$out"
expect "empty HOME" "cannot be used" "$out"
expect "empty HOME" "connector" "$out"
one_line "empty HOME" "$out"

mkdir -p "$home/.starzero" && printf '{}\n' > "$home/.starzero/credentials"
out=$(HOME="$home" STARZERO_API_KEY='' "$hook")
expect "credentials file present" "is logged in" "$out"
expect "credentials file present" "connector" "$out"
lacks "credentials file present" "/starzero:setup" "$out"
one_line "credentials file present" "$out"

out=$(HOME="$home/none" STARZERO_API_KEY=key "$hook")
expect "STARZERO_API_KEY set" "is logged in" "$out"
lacks "STARZERO_API_KEY set" "/starzero:setup" "$out"

mkdir -p "$home/cfg" && printf '{}\n' > "$home/cfg/credentials"
out=$(HOME="$home/none" STARZERO_API_KEY='' STARZERO_CONFIG_DIR="$home/cfg" "$hook")
expect "STARZERO_CONFIG_DIR credentials" "is logged in" "$out"
lacks "STARZERO_CONFIG_DIR credentials" "/starzero:setup" "$out"

env_file="$home/env"
out=$(HOME="$home/none" STARZERO_API_KEY=key CLAUDE_ENV_FILE="$env_file" "$hook")
expect "with CLAUDE_ENV_FILE" "is logged in" "$out"
grep -q "^export PATH=\"$root/scripts:\$PATH\"$" "$env_file" || { printf 'FAIL env file lacks the PATH line:\n'; cat "$env_file"; exit 1; }

printf 'ok   session-start says logged in or setup first, names the connector as optional, and puts scripts/ on PATH\n'
