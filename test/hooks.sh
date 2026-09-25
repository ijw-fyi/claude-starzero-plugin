#!/bin/sh
# Exercises hooks/consent.sh and hooks/session-start.sh with canned input. No network.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
failures=0

check() {
  # check <label> <expected: ask|pass> <command text>
  input=$(printf '{\n  "tool_name": "Bash",\n  "tool_input": {\n    "command": "%s",\n    "description": "a \\"command\\": that mentions starzero chat send"\n  },\n  "tool_use_id": "toolu_1"\n}\n' "$3")
  output=$(printf '%s' "$input" | "$root/hooks/consent.sh")
  case "$2" in
    ask) ok=$(printf '%s' "$output" | grep -c '"permissionDecision":"ask"' || true) ;;
    pass) ok=$([ -z "$output" ] && echo 1 || echo 0) ;;
  esac
  if [ "$ok" = 1 ]; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s\n  input: %s\n  output: %s\n' "$1" "$3" "$output"
    failures=$((failures + 1))
  fi
}

check "upload asks" ask 'starzero media upload --library lib_1 --folder /raw a.mp4'
check "upload by absolute path asks" ask '/home/me/.claude/plugins/starzero/scripts/starzero media upload --library lib_1 a.mp4'
check "upload dry-run passes" pass 'starzero media upload --library lib_1 --dry-run a.mp4'
check "workflow create asks" ask 'starzero workflow instance create --template t_1 --library lib_1 --variables vars.json'
check "workflow create by absolute path asks" ask '/home/me/.claude/plugins/starzero/scripts/starzero workflow instance create --template t_1 --library lib_1'
check "workflow create with global flag first asks" ask 'starzero --json workflow instance create --template t_1 --library lib_1'
check "workflow create after cd asks" ask 'cd /tmp && starzero workflow instance create --template t_1 --library lib_1 --json'
check "podcast create asks" ask 'starzero podcast-clips create --library lib_1 --media m_1 --auto'
check "chat send asks" ask 'starzero chat send c_1 --message \\"hello\\"'
check "chat send with escaped newline asks" ask 'starzero chat send c_1 \\\n  --message hi'
check "windows exe asks" ask 'C:\\\\Users\\\\me\\\\.starzero\\\\bin\\\\0.3.1\\\\starzero.exe chat send c_1 --message hi'
check "clean render asks" ask 'starzero output render --library lib_1 --clip m_1:12.5-30 --no-watermark'
check "watermarked render passes" pass 'starzero output render --library lib_1 --clip m_1:12.5-30 --json'
check "skip-credit-check asks" ask 'starzero media upload --library lib_1 --dry-run --skip-credit-check a.mp4'
check "media list passes" pass 'starzero media list --library lib_1 --json'
check "workflow instance get passes" pass 'starzero workflow instance get i_1'
check "chat get passes" pass 'starzero chat get c_1 --json'
check "help passes" pass 'starzero chat send --help'
check "version passes" pass 'starzero --version'
check "unrelated command passes" pass 'git status'
check "no command key passes" pass ''

output=$(printf '{"tool_name":"Bash","tool_input":{"command":"starzero chat send c_1 --message hi"}}' \
  | CLAUDE_PLUGIN_OPTION_CONFIRM_BILLED_COMMANDS=false "$root/hooks/consent.sh")
if [ -z "$output" ]; then printf 'ok   option off passes\n'; else printf 'FAIL option off passes\n'; failures=$((failures + 1)); fi

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
