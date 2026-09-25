#!/bin/sh
# SessionStart hook: puts the launcher on PATH for the session and hands the plugin's API key
# option to the CLI. Fast and offline; the launcher downloads the CLI on first use instead.
#
# Key handoff: the option value is written to the CLI's credentials file
# ($STARZERO_CONFIG_DIR/credentials, default ~/.starzero/credentials; one line, mode 0600),
# and STARZERO_KEYRING=0 is exported so the CLI reads that file. Writing the file directly
# (instead of `starzero auth login`) is what makes the key available in the very first session,
# before the binary exists. While the plugin option is set it is the source of truth for the file;
# clear the option to manage the key with `starzero auth` instead.
#
# FIXME: the credentials file is a plaintext 0600 copy of a key Claude Code already holds in its
# own secure store. Acceptable once: the keychain is not reachable from every sandbox and the
# binary is absent on first run. Retire when the CLI can import this file into the OS keychain
# (planned `starzero auth migrate`), at which point this hook stops exporting STARZERO_KEYRING=0.
set -eu

root="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is set by Claude Code for plugin hooks}"
config_dir="${STARZERO_CONFIG_DIR:-$HOME/.starzero}"
credentials="$config_dir/credentials"

# Git Bash on Windows hands over a C:\ path; PATH entries there need the /c/ form.
if command -v cygpath >/dev/null 2>&1; then
  root=$(cygpath -u "$root")
fi

key="${CLAUDE_PLUGIN_OPTION_API_KEY:-}"
if [ -n "$key" ]; then
  current=""
  [ -f "$credentials" ] && current=$(tr -d '[:space:]' < "$credentials")
  if [ "$current" != "$key" ]; then
    umask 077
    mkdir -p "$config_dir"
    chmod 700 "$config_dir"
    printf '%s\n' "$key" > "$credentials"
    chmod 600 "$credentials"
  fi
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    # SessionStart also fires on clear and compact; the guard keeps PATH from growing each time.
    # shellcheck disable=SC2016  # $PATH is meant for the shell that sources the env file
    printf 'case ":$PATH:" in *":%s/scripts:"*) ;; *) export PATH="%s/scripts:$PATH" ;; esac\n' "$root" "$root"
    # A credentials file present (written here, or by the user with STARZERO_KEYRING=0) is the
    # store to read. Without one the CLI keeps its default order: STARZERO_API_KEY, then keychain.
    [ -f "$credentials" ] && printf 'export STARZERO_KEYRING=0\n'
  } >> "$CLAUDE_ENV_FILE"
fi

exit 0
