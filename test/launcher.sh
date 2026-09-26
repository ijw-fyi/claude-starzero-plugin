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

# Keyring selection: with a credentials file and STARZERO_KEYRING unset, the launcher runs the CLI
# in file mode; an explicit STARZERO_KEYRING leaves the choice alone.
# The installed binary is swapped for a stub that prints the variable.
mv "$home/.starzero/bin/$want/starzero" "$home/.starzero/bin/$want/starzero.real"
# shellcheck disable=SC2016  # the stub prints the variable at its own run time
printf '#!/bin/sh\nprintf %%s "${STARZERO_KEYRING-unset}"\n' > "$home/.starzero/bin/$want/starzero"
chmod +x "$home/.starzero/bin/$want/starzero"
keyring_with() {
  # keyring_with <file content or -> [env assignment]
  if [ "$1" = - ]; then rm -f "$home/.starzero/credentials"; else printf '%s' "$1" > "$home/.starzero/credentials"; fi
  shift
  env -u STARZERO_KEYRING HOME="$home" "$@" "$root/scripts/starzero"
}
[ "$(keyring_with -)" = unset ] || { printf 'FAIL no credentials file should leave STARZERO_KEYRING unset\n'; exit 1; }
[ "$(keyring_with '{"type":"api-key"}')" = 0 ] || { printf 'FAIL a credentials file should select file mode\n'; exit 1; }
[ "$(keyring_with '{"type":"api-key"}' STARZERO_KEYRING=1)" = 1 ] || { printf 'FAIL an explicit STARZERO_KEYRING should win\n'; exit 1; }
printf 'ok   launcher selects file mode when a credentials file exists\n'
