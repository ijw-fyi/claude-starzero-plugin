#!/bin/sh
# PreToolUse hook for Bash and PowerShell: asks the user before a starzero command that spends
# credits runs. Everything else passes through silently. The plugin option
# confirm_billed_commands (default on) turns this off.
#
# Billed commands: media upload (a --dry-run is free), workflow instance create,
# podcast-clips create, chat send, output render --no-watermark (the watermarked default is free).
# --skip-credit-check also asks, since it removes the CLI's own stop. --help and --version never
# bill, so they pass. The skills put the estimate in the Bash call's description, which the
# permission box shows next to this hook's reason.
set -eu

case "${CLAUDE_PLUGIN_OPTION_CONFIRM_BILLED_COMMANDS:-true}" in
  false|0|off|no) exit 0 ;;
esac

# The command string out of the hook's JSON input: the first "command" key, with JSON escapes
# resolved and line breaks turned into spaces. Plain awk, so it runs everywhere sh does.
command_text=$(awk '
  { buf = buf $0 " " }
  END {
    start = index(buf, "\"command\"")
    if (start == 0) exit
    rest = substr(buf, start + 9)
    if (match(rest, /^[ \t]*:[ \t]*"/) == 0) exit
    rest = substr(rest, RLENGTH + 1)
    out = ""
    n = length(rest)
    for (k = 1; k <= n; k++) {
      c = substr(rest, k, 1)
      if (c == "\\") {
        k++
        d = substr(rest, k, 1)
        if (d == "n" || d == "t" || d == "r") out = out " "
        else if (d == "u") { out = out " "; k += 4 }
        else out = out d
      } else if (c == "\"") {
        break
      } else {
        out = out c
      }
    }
    print out
  }')

[ -n "$command_text" ] || exit 0

matches() { printf '%s' "$command_text" | grep -Eq -- "$1"; }

# "starzero" (or starzero.exe, by any path), optional global flags, then the subcommand words.
prefix='starzero(\.exe)?[[:space:]]+([^|;&]*[[:space:]])?'
sp='[[:space:]]+'

matches "(^|[[:space:]])--(help|version)([[:space:]]|$)" && exit 0

reason=""
if matches "${prefix}media${sp}upload" && ! matches '(^|[[:space:]])--dry-run([[:space:]]|$)'; then
  reason="starzero media upload spends credits on processing. Confirm to run it, or ask for a --dry-run estimate first."
elif matches "${prefix}workflow${sp}instance${sp}create"; then
  reason="starzero workflow instance create starts a billed run. Confirm to run it."
elif matches "${prefix}podcast-clips${sp}create"; then
  reason="starzero podcast-clips create starts a billed run. Confirm to run it."
elif matches "${prefix}chat${sp}send"; then
  reason="starzero chat send is a billed agent turn. Confirm to run it."
elif matches "${prefix}output${sp}render" && matches '(^|[[:space:]])--no-watermark([[:space:]]|$)'; then
  reason="starzero output render --no-watermark is a clean render that spends credits per minute. Confirm to run it, or drop --no-watermark for a free watermarked preview."
elif matches "${prefix}[^|;&]*--skip-credit-check"; then
  reason="--skip-credit-check removes the CLI's credit check before a billed upload. Confirm to run it."
fi

[ -n "$reason" ] || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
