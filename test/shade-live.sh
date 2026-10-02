#!/bin/sh
# Live smoke test for scripts/shade against a real Shade account. Opt-in: needs a stored key
# (`shade login --stdin`) or SHADE_API_KEY, rclone 1.73+, jq and the network, so CI never runs it.
#
# Everything is derived from the account: the first workspace, the first drive (or
# SHADE_SMOKE_DRIVE=<uuid>), and the first file at the drive root as the sample for the signed URL.
# The run writes a small text file under /_smoke-<stamp>/ on the drive, and with --roundtrip also
# downloads the sample file, re-uploads it there and compares the bytes. The script has no delete,
# so the folder is named at the end for trashing in the Shade app.
#
#   SHADE_BIN=/path/to/shade test/shade-live.sh [--roundtrip]
set -u

roundtrip=0
case "${1:-}" in
  "") ;;
  --roundtrip) roundtrip=1 ;;
  *) printf 'usage: %s [--roundtrip]\n' "$0" >&2; exit 2 ;;
esac

# ---- the script under test --------------------------------------------------------------------
here=$(cd "$(dirname "$0")" && pwd)
if [ -n "${SHADE_BIN:-}" ]; then shade=$SHADE_BIN
elif [ -x "$here/../scripts/shade" ]; then shade=$(cd "$here/../scripts" && pwd)/shade
elif command -v shade >/dev/null 2>&1; then shade=$(command -v shade)
else
  printf 'shade-live: cannot find the shade script: set SHADE_BIN=/path/to/shade, run this from a checkout (test/shade-live.sh next to scripts/shade), or put scripts/ on PATH\n' >&2
  exit 2
fi

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT INT TERM
stamp=$(date +%Y%m%d-%H%M%S)
folder="/_smoke-$stamp"
fails=0

check() {
  # check <expected exit> <label> <command...>: stdout lands in $out, stderr in $err
  want=$1; label=$2; shift 2
  out=$("$@" 2>"$tmp/err"); got=$?
  err=$(cat "$tmp/err")
  if [ "$got" -ne "$want" ]; then
    printf 'FAIL %s: exit %s, expected %s\n  stdout: %s\n  stderr: %s\n' "$label" "$got" "$want" "$out" "$err"; fails=$((fails + 1))
  else printf 'ok   %s (exit %s)\n' "$label" "$got"; fi
}
contains() { case "$2" in *"$3"*) ;; *) printf 'FAIL %s: expected "%s" in:\n%s\n' "$1" "$3" "$2"; fails=$((fails + 1)) ;; esac; }
indent() { sed 's/^/     /'; }

printf 'shade-live: testing %s\n\n' "$shade"

# ---- tools and key ----------------------------------------------------------------------------
printf '## status\n'
status_out=$("$shade" status 2>&1); status_exit=$?
printf '%s\n' "$status_out" | indent
case "$status_exit" in
  0) ;;
  3) printf '\nshade-live: no usable key. In your own terminal run:\n\n  %s login --stdin\n\nand paste a key from the Shade app (Settings > API Keys), then run this again.\n' "$shade" >&2; exit 3 ;;
  *) printf '\nshade-live: status exited %s; fix the tools above first\n' "$status_exit" >&2; exit 1 ;;
esac

# ---- discovery: workspace, drive, sample file --------------------------------------------------
printf '\n## workspaces and drives\n'
check 0 "workspaces" "$shade" workspaces; printf '%s\n' "$out" | indent
ws_id=$(printf '%s\n' "$out" | sed -n '2p' | cut -c1-36)
ws_name=$(printf '%s\n' "$out" | sed -n '2p' | cut -c39-70 | sed 's/ *$//')
[ -n "$ws_id" ] || { printf 'shade-live: the key sees no workspace; nothing to test\n' >&2; exit 1; }
contains "status counted a workspace" "$status_out" "access   "
check 0 "drives" "$shade" drives; printf '%s\n' "$out" | indent
drive_id=${SHADE_SMOKE_DRIVE:-$(printf '%s\n' "$out" | sed -n '2p' | cut -c1-36)}
[ -n "$drive_id" ] || { printf 'shade-live: the key sees no drive; nothing to test\n' >&2; exit 1; }
contains "drives lists the chosen drive" "$out" "$drive_id"
check 0 "drives --workspace" "$shade" drives --workspace "$ws_id"
check 4 "drives --workspace unknown -> 4" "$shade" drives --workspace 99999999-9999-9999-9999-999999999999
check 2 "drives --workspace non-uuid -> 2" "$shade" drives --workspace acme
printf '     using workspace %s (%s), drive %s\n' "$ws_id" "$ws_name" "$drive_id"

printf '\n## ls\n'
check 0 "ls /" "$shade" ls "$drive_id" /; printf '%s\n' "$out" | indent
sample_line=$(printf '%s\n' "$out" | grep -v '^-1  ' | sed -n '1p')
sample_name=$(printf '%s\n' "$sample_line" | sed 's/^[0-9]*  //')
sample_size=$(printf '%s\n' "$sample_line" | sed 's/  .*//')
if [ -n "$sample_name" ]; then printf '     sample file: "%s" (%s bytes)\n' "$sample_name" "$sample_size"
else printf '     no file at the drive root: the signed-URL and round-trip checks on an existing file are skipped\n'; fi
check 4 "ls of a missing folder -> 4" "$shade" ls "$drive_id" "/Nowhere-$stamp"; printf '%s\n' "$err" | indent
check 2 "ls with a non-uuid drive -> 2" "$shade" ls marketing /

# ---- upload -------------------------------------------------------------------------------------
printf '\n## upload\n'
printf 'hello from the shade smoke test %s\n' "$stamp" > "$tmp/hello.txt"
check 0 "upload into a new folder" "$shade" upload "$drive_id" "$tmp/hello.txt" "$folder/hello.txt"; printf '%s\n' "$out" | indent
check 8 "upload onto the existing file -> 8" "$shade" upload "$drive_id" "$tmp/hello.txt" "$folder/hello.txt"
contains "conflict names --force" "$err" "--force"
printf 'second version, different length %s\n' "$stamp" > "$tmp/hello.txt"
check 0 "upload --force" "$shade" upload "$drive_id" "$tmp/hello.txt" "$folder/hello.txt"  --force; printf '%s\n' "$out" | indent
contains "forced upload reports the new size" "$out" "uploaded  $(wc -c < "$tmp/hello.txt" | tr -d ' ') bytes"
check 8 "upload onto a folder path -> 8" "$shade" upload "$drive_id" "$tmp/hello.txt" "$folder"
check 2 "upload of a missing local file -> 2" "$shade" upload "$drive_id" "$tmp/none.txt" "$folder/none.txt"
check 0 "ls the new folder" "$shade" ls "$drive_id" "$folder"; printf '%s\n' "$out" | indent
check 0 "ls / shows the folder" "$shade" ls "$drive_id" /
contains "folder entry ends with /" "$out" "-1  ${folder#/}/"

# ---- download -----------------------------------------------------------------------------------
printf '\n## download\n'
check 0 "download" "$shade" download "$drive_id" "$folder/hello.txt" "$tmp/back.txt"; printf '%s\n' "$out" | indent
if cmp -s "$tmp/hello.txt" "$tmp/back.txt"; then printf 'ok   downloaded bytes match\n'; else printf 'FAIL downloaded bytes differ\n'; fails=$((fails + 1)); fi
check 8 "download onto an existing local file -> 8" "$shade" download "$drive_id" "$folder/hello.txt" "$tmp/back.txt"
check 0 "download --force" "$shade" download "$drive_id" "$folder/hello.txt" "$tmp/back.txt" --force
check 4 "download of a missing file -> 4" "$shade" download "$drive_id" "$folder/missing.txt" "$tmp/missing.txt"; printf '%s\n' "$err" | indent
check 2 "download of a folder -> 2" "$shade" download "$drive_id" "$folder" "$tmp/folder.bin"

# ---- url ----------------------------------------------------------------------------------------
printf '\n## url\n'
check 0 "url of the uploaded file" "$shade" url "$drive_id" "$folder/hello.txt"
case "$out" in https://*) printf 'ok   url is https\n' ;; *) printf 'FAIL url is not https: %s\n' "$out"; fails=$((fails + 1)) ;; esac
curl -sS --max-time 60 -o "$tmp/url-body.txt" "$out" 2>"$tmp/curl.err"
if cmp -s "$tmp/hello.txt" "$tmp/url-body.txt"; then printf 'ok   signed url serves the uploaded bytes\n'
else printf 'FAIL signed url body differs: %s %s\n' "$(cat "$tmp/curl.err")" "$(head -c 200 "$tmp/url-body.txt")"; fails=$((fails + 1)); fi
check 4 "url of a missing path -> 4" "$shade" url "$drive_id" "$folder/missing.txt"; printf '%s\n' "$err" | indent
check 4 "url of a folder -> 4" "$shade" url "$drive_id" "$folder"
if [ -n "$sample_name" ]; then
  check 0 "url of the sample file" "$shade" url "$drive_id" "/$sample_name"
  url=$out
  # presigned URLs are signed for GET (a HEAD is refused), so fetch one byte and read Content-Range
  curl -sS -D "$tmp/url-head.txt" -o "$tmp/url-byte" -r 0-0 --max-time 60 "$url" 2>"$tmp/curl.err"
  code=$(sed -n '1s/.* \([0-9][0-9][0-9]\).*/\1/p' "$tmp/url-head.txt")
  total=$(tr -d '\r' < "$tmp/url-head.txt" | awk 'tolower($1)=="content-range:" {sub(".*/", "", $3); print $3}')
  printf '     ranged GET on the signed url: HTTP %s, total size %s (ls said %s)\n' "$code" "$total" "$sample_size"
  [ "$code" = "206" ] || { printf 'FAIL ranged GET on the signed url is not 206: %s\n' "$(cat "$tmp/curl.err")"; fails=$((fails + 1)); }
  [ "$total" = "$sample_size" ] || { printf 'FAIL signed url total size differs from ls\n'; fails=$((fails + 1)); }
else printf 'skip url of an existing file (no file at the drive root)\n'; fi

# ---- round trip ---------------------------------------------------------------------------------
if [ "$roundtrip" -eq 1 ] && [ -n "$sample_name" ]; then
  printf '\n## round trip of "%s" (%s bytes)\n' "$sample_name" "$sample_size"
  check 0 "download the sample file" "$shade" download "$drive_id" "/$sample_name" "$tmp/sample"; printf '%s\n' "$out" | indent
  check 0 "re-upload it under the smoke folder" "$shade" upload "$drive_id" "$tmp/sample" "$folder/$sample_name"; printf '%s\n' "$out" | indent
  check 0 "download the copy" "$shade" download "$drive_id" "$folder/$sample_name" "$tmp/sample-copy"
  if cmp -s "$tmp/sample" "$tmp/sample-copy"; then printf 'ok   the copy matches the original byte for byte\n'
  else printf 'FAIL the copy differs from the original\n'; fails=$((fails + 1)); fi
elif [ "$roundtrip" -eq 1 ]; then printf '\nskip round trip (no file at the drive root)\n'; fi

# ---- key handling -------------------------------------------------------------------------------
printf '\n## key handling\n'
check 3 "bogus SHADE_API_KEY on workspaces -> 3" env SHADE_API_KEY=sk_bogus_smoke "$shade" workspaces; printf '%s\n' "$err" | indent
check 3 "bogus SHADE_API_KEY on ls -> 3" env SHADE_API_KEY=sk_bogus_smoke "$shade" ls "$drive_id" /; printf '%s\n' "$err" | indent
contains "the refusal names the key source" "$err" "SHADE_API_KEY"

# ---- verdict ------------------------------------------------------------------------------------
printf '\nleft on drive %s: %s/ (trash it in the Shade app; the script has no delete)\n' "$drive_id" "$folder"
if [ "$fails" -eq 0 ]; then printf 'ALL OK\n'; else printf '%s check(s) failed\n' "$fails"; exit 1; fi
