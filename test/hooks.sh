#!/bin/sh
# Exercises hooks/session-start.sh with canned input. No network.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
failures=0

# session-start.sh: writes the credentials file once, exports PATH and the keyring switch.
home=$(mktemp -d)
env_file="$home/env"
run_session_start() {
  HOME="$home" CLAUDE_PLUGIN_ROOT="$root" CLAUDE_ENV_FILE="$env_file" \
    CLAUDE_PLUGIN_OPTION_API_KEY="${1-}" "$root/hooks/session-start.sh"
}
: > "$env_file"
run_session_start ""
# shellcheck disable=SC1090  # the env file is what the hook just wrote
if grep -q "scripts:\$PATH" "$env_file" && ! grep -q STARZERO_KEYRING "$env_file" && [ ! -e "$home/.starzero/credentials" ] \
  && (PATH=/usr/bin; . "$env_file"; [ "$PATH" = "$root/scripts:/usr/bin" ] && . "$env_file" && [ "$PATH" = "$root/scripts:/usr/bin" ]); then
  printf 'ok   session-start without a key exports PATH only\n'
else
  printf 'FAIL session-start without a key\n  env: %s\n' "$(cat "$env_file")"; failures=$((failures + 1))
fi
: > "$env_file"
run_session_start "sz_test_key"
mode=$(stat -c %a "$home/.starzero/credentials" 2>/dev/null || stat -f %Lp "$home/.starzero/credentials")
if [ "$(cat "$home/.starzero/credentials")" = "sz_test_key" ] && [ "$mode" = 600 ] && grep -q 'STARZERO_KEYRING=0' "$env_file"; then
  printf 'ok   session-start with a key writes credentials (0600) and exports the keyring switch\n'
else
  printf 'FAIL session-start with a key\n  mode: %s env: %s\n' "$mode" "$(cat "$env_file")"; failures=$((failures + 1))
fi
before=$(stat -c %Y "$home/.starzero/credentials" 2>/dev/null || stat -f %m "$home/.starzero/credentials")
sleep 1
run_session_start "sz_test_key"
after=$(stat -c %Y "$home/.starzero/credentials" 2>/dev/null || stat -f %m "$home/.starzero/credentials")
if [ "$before" = "$after" ]; then
  printf 'ok   session-start leaves an unchanged key alone\n'
else
  printf 'FAIL session-start rewrote an unchanged key\n'; failures=$((failures + 1))
fi
rm -rf "$home"

[ "$failures" -eq 0 ] || { printf '%s hook test(s) failed\n' "$failures"; exit 1; }
printf 'all hook tests passed\n'
