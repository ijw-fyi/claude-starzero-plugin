#!/bin/sh
# Offline test for scripts/shade: fake `curl` and `rclone` on PATH stand in for Shade and the
# transfer tool, and record what they were called with. Real jq is required (CI installs it).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT INT TERM
shade="$root/scripts/shade"
shim="$home/bin"
mkdir -p "$shim" "$home/remote"
export HOME="$home" PATH="$shim:$PATH" SHIM_HOME="$home"
unset SHADE_API_KEY STARZERO_CONFIG_DIR || true

ws1=11111111-1111-1111-1111-111111111111
drive1=aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
drive2=bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb

# ---- fake curl: honours -K - (config on stdin), -o <file>, -w, and the last URL argument -------
cat > "$shim/curl" <<'CURL'
#!/bin/sh
printf '%s\n' "$*" >> "$SHIM_HOME/curl.log"
out=/dev/stdout; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -K) shift; [ "$1" = "-" ] && cat > "$SHIM_HOME/curl-config" ;;
    -o) shift; out=$1 ;;
    -w|--connect-timeout|--max-time) shift ;;
    http*) url=$1 ;;
  esac
  shift
done
printf '%s\n' "$url" >> "$SHIM_HOME/curl-urls.log"
if ! grep -q '^header = "Authorization: sk_good"$' "$SHIM_HOME/curl-config"; then
  printf '{"type":"about:blank","detail":"Unauthorized","status":401}' > "$out"; printf 401; exit 0
fi
path=${url#*api.shade.inc}
case "$path" in
  /workspaces) printf '[{"id":"11111111-1111-1111-1111-111111111111","name":"Acme","domain":"acme"}]' > "$out"; printf 200 ;;
  /workspaces/11111111-1111-1111-1111-111111111111/drives)
    printf '[{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","name":"Marketing"},{"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","name":"Raw Footage"}]' > "$out"; printf 200 ;;
  /assets/path?*missing*) printf '{"type":"about:blank","detail":"Asset not found","status":404}' > "$out"; printf 404 ;;
  /assets/path?*) printf '{"id":"cccccccc-cccc-cccc-cccc-cccccccccccc","name":"clip.mp4","size_bytes":16}' > "$out"; printf 200 ;;
  /assets/cccccccc-cccc-cccc-cccc-cccccccccccc/download?*) printf '"https://storage.example.test/signed/clip.mp4?sig=abc"' > "$out"; printf 200 ;;
  *) printf '{"detail":"no route"}' > "$out"; printf 404 ;;
esac
CURL

# ---- fake rclone: version, lsjson --stat, lsf, copyto over a directory tree under $home/remote --
cat > "$shim/rclone" <<'RCLONE'
#!/bin/sh
printf 'argv: %s\n' "$*" >> "$SHIM_HOME/rclone.log"
cfg=""; prev=""
for a in "$@"; do [ "$prev" = "--config" ] && cfg=$a; prev=$a; done
if [ -n "$cfg" ] && [ -f "$cfg" ] && [ ! -s "$cfg" ]; then cfg_state=empty-file; else cfg_state="$cfg"; fi
printf 'env: key=%s drive=%s config=%s\n' "${RCLONE_SHADE_API_KEY:-unset}" "${RCLONE_SHADE_DRIVE_ID:-unset}" "$cfg_state" >> "$SHIM_HOME/rclone.log"
remote="$SHIM_HOME/remote"
case "$*" in *version*) ;; *)
  if [ "${RCLONE_SHADE_API_KEY:-}" != "sk_good" ]; then
    printf 'CRITICAL: Failed to create file system for ":shade:/": failed to get ShadeFS token: HTTP error 401 (401 Unauthorized)\n' >&2; exit 1
  fi ;;
esac
cmd=""; ignore_times=0; a1=""; a2=""; skip=0
for arg in "$@"; do
  if [ "$skip" -eq 1 ]; then skip=0; continue; fi
  case "$arg" in
    version|lsjson|lsf|copyto) cmd=$arg ;;
    --ignore-times) ignore_times=1 ;;
    --format|--separator|--contimeout|--timeout|--retries|--low-level-retries|--config) skip=1 ;;
    --*|-q) ;;
    *) [ -n "$cmd" ] && { if [ -z "$a1" ]; then a1=$arg; else a2=$arg; fi; } ;;
  esac
done
case "$cmd" in
  version) printf 'rclone v%s\n- os/version: test\n' "${SHIM_RCLONE_VERSION:-1.75.0}" ;;
  lsjson)
    [ -z "${SHIM_LSJSON_FATAL:-}" ] || { printf 'ERROR : connection reset by peer\n' >&2; exit 7; }
    p="$remote/${a1#:shade:}"
    if [ -d "$p" ]; then printf '{"IsDir":true,"Size":-1}\n'
    elif [ -f "$p" ]; then printf '{"IsDir":false,"Size":%s}\n' "$(wc -c < "$p" | tr -d ' ')"
    else printf 'ERROR : object not found\n' >&2; exit 4; fi ;;
  lsf)
    p="$remote/${a1#:shade:}"
    [ -d "$p" ] || { printf 'ERROR : directory not found\n' >&2; exit 3; }
    for e in "$p"/*; do [ -e "$e" ] || continue
      if [ -d "$e" ]; then printf -- '-1  %s/\n' "$(basename "$e")"; else printf '%s  %s\n' "$(wc -c < "$e" | tr -d ' ')" "$(basename "$e")"; fi
    done ;;
  copyto)
    case "$a1" in
      :shade:*) src="$remote/${a1#:shade:}"; dst=$a2 ;;
      *) src=$a1; dst="$remote/${a2#:shade:}" ;;
    esac
    [ "$ignore_times" -eq 1 ] && printf 'copyto: ignore-times\n' >> "$SHIM_HOME/rclone.log"
    mkdir -p "$(dirname "$dst")" && cp "$src" "$dst" ;;
  *) printf 'fake rclone: unknown command in: %s\n' "$*" >&2; exit 1 ;;
esac
RCLONE
chmod +x "$shim/curl" "$shim/rclone"

fails=0
check() {
  # check <expected exit> <label> <command...>: runs it, stores stdout in $out and stderr in $err
  want=$1; label=$2; shift 2
  set +e
  out=$("$@" 2>"$home/err"); got=$?
  set -e
  err=$(cat "$home/err")
  if [ "$got" -ne "$want" ]; then
    printf 'FAIL %s: exit %s, expected %s\nstdout: %s\nstderr: %s\n' "$label" "$got" "$want" "$out" "$err"; fails=$((fails + 1))
  fi
}
contains() {
  # contains <label> <haystack> <needle>
  case "$2" in *"$3"*) ;; *) printf 'FAIL %s: expected to find "%s" in:\n%s\n' "$1" "$3" "$2"; fails=$((fails + 1)) ;; esac
}
lacks() {
  case "$2" in *"$3"*) printf 'FAIL %s: did not expect "%s" in:\n%s\n' "$1" "$3" "$2"; fails=$((fails + 1)) ;; esac
}

# usage
check 2 "no command" "$shade"
check 2 "unknown command" "$shade" bogus
check 0 "--help" "$shade" --help
contains "--help lists upload" "$out" "upload <drive> <file> <dest-path>"

# status before anything is set up
check 3 "status without a key" "$shade" status
contains "status names the login step" "$out" "shade login --stdin"
contains "status reports rclone ok" "$out" "rclone   ok  1.75.0"

# an old rclone is refused with the install hint, and the version check runs before the network
SHIM_RCLONE_VERSION=1.60.1 check 1 "old rclone on status" "$shade" status
contains "old rclone names the version" "$out" "too old (1.60.1;"
contains "old rclone gives the install hint" "$out" "rclone.org/install"
printf 'sk_good\n' > "$home/key.txt"
SHIM_RCLONE_VERSION=1.60.1 SHADE_API_KEY=sk_good check 1 "old rclone on workspaces" "$shade" workspaces
contains "old rclone hint on a command" "$err" "rclone.org/install"

# login: a refused key stores nothing; a good key lands in an owner-only file
check 2 "login with the key as an argument" "$shade" login sk_good
printf 'sk_bad\n' > "$home/bad-key.txt"
check 3 "login with a refused key" "$shade" login --stdin < "$home/bad-key.txt"
[ ! -e "$home/.starzero/shade-credentials" ] || { printf 'FAIL refused key was stored\n'; fails=$((fails + 1)); }
check 0 "login --stdin" "$shade" login --stdin < "$home/key.txt"
contains "login names the workspace" "$out" "Acme"
lacks "login prints no key" "$out" "sk_good"
[ "$(tr -d '\n' < "$home/.starzero/shade-credentials")" = "sk_good" ] || { printf 'FAIL stored key differs\n'; fails=$((fails + 1)); }
# shellcheck disable=SC2012 # ls -l reads the mode bits portably (stat differs on macOS)
mode=$(ls -l "$home/.starzero/shade-credentials" | cut -c2-10)
[ "$mode" = "rw-------" ] || { printf 'FAIL credentials mode is %s, expected rw-------\n' "$mode"; fails=$((fails + 1)); }

# a group-readable credentials file is refused
chmod 640 "$home/.starzero/shade-credentials"
check 3 "world-readable credentials" "$shade" workspaces
contains "insecure file names chmod" "$err" "chmod 600"
# ... except under Git Bash, where mode bits are emulated: a fake uname says Windows
printf '#!/bin/sh\necho MINGW64_NT-10.0\n' > "$shim/uname" && chmod +x "$shim/uname"
check 0 "group-readable credentials are accepted on Windows" "$shade" workspaces
rm "$shim/uname"
chmod 600 "$home/.starzero/shade-credentials"

# status, workspaces, drives
check 0 "status with a key" "$shade" status
contains "status shows the key source" "$out" "key      from $home/.starzero/shade-credentials"
contains "status shows access" "$out" "access   1 workspace(s): Acme"
lacks "status prints no key" "$out" "sk_good"
check 0 "workspaces" "$shade" workspaces
contains "workspaces table" "$out" "$ws1  Acme"
check 0 "drives" "$shade" drives
contains "drives lists Marketing" "$out" "$drive1  Marketing"
contains "drives lists Raw Footage with its workspace" "$out" "Raw Footage                     Acme"
check 0 "drives --workspace" "$shade" drives --workspace "$ws1"
check 4 "drives --workspace unknown" "$shade" drives --workspace 99999999-9999-9999-9999-999999999999
check 2 "drives with a non-UUID" "$shade" drives --workspace acme

# ls maps rclone's "directory not found" (exit 3) to 4, never to 3
mkdir -p "$home/remote/Project" && printf 'abc' > "$home/remote/Project/notes.txt"
check 0 "ls" "$shade" ls "$drive1" /Project
contains "ls prints the file" "$out" "3  notes.txt"
check 4 "ls of a missing folder" "$shade" ls "$drive1" /Nowhere
check 2 "ls with a bad drive id" "$shade" ls marketing /

# upload: new file, existing destination, --force
printf 'video bytes here' > "$home/clip.mp4"
check 0 "upload" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/clip.mp4
contains "upload reports size and path" "$out" "uploaded  16 bytes  /StarZero/clip.mp4"
cmp -s "$home/clip.mp4" "$home/remote/StarZero/clip.mp4" || { printf 'FAIL uploaded bytes differ\n'; fails=$((fails + 1)); }
contains "rclone got the key through the environment and an empty config file" "$(cat "$home/rclone.log")" "env: key=sk_good drive=$drive1 config=empty-file"
contains "rclone runs without a password prompt" "$(cat "$home/rclone.log")" "--ask-password=false"
lacks "fresh upload does not force" "$(cat "$home/rclone.log")" "ignore-times"
check 8 "upload onto an existing file" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/clip.mp4
contains "conflict names --force" "$err" "--force"
printf 'new video bytes' > "$home/clip.mp4"
check 0 "upload --force" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/clip.mp4 --force
contains "forced upload passes --ignore-times" "$(cat "$home/rclone.log")" "copyto: ignore-times"
check 8 "upload onto a folder path" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero
check 2 "upload of a missing file" "$shade" upload "$drive1" "$home/none.mp4" /StarZero/none.mp4
check 2 "upload to a folder-shaped dest" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/

# a failing existence check aborts the upload instead of reading as "destination free"
: > "$home/rclone.log"
SHIM_LSJSON_FATAL=1 check 1 "upload when the existence check fails" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/third.mp4
contains "failed check names rclone's error" "$err" "connection reset"
lacks "no copyto after a failed existence check" "$(cat "$home/rclone.log")" "copyto"
SHIM_LSJSON_FATAL=1 check 1 "download when the existence check fails" "$shade" download "$drive1" /StarZero/clip.mp4 "$home/out/again.mp4"
[ ! -e "$home/out/again.mp4" ] || { printf 'FAIL download ran after a failed check\n'; fails=$((fails + 1)); }

# download: existing local file is a conflict; a missing remote file is not found
check 8 "download onto an existing local file" "$shade" download "$drive1" /StarZero/clip.mp4 "$home/clip.mp4"
check 0 "download" "$shade" download "$drive1" /StarZero/clip.mp4 "$home/out/clip.mp4"
cmp -s "$home/remote/StarZero/clip.mp4" "$home/out/clip.mp4" || { printf 'FAIL downloaded bytes differ\n'; fails=$((fails + 1)); }
check 4 "download of a missing file" "$shade" download "$drive1" /StarZero/missing.mp4 "$home/out/missing.mp4"

# url: the drive-prefixed path resolves to an asset id, which signs the URL; the JSON string unwrapped
check 0 "url" "$shade" url "$drive2" "/Raw/Ep 1/clip.mp4"
[ "$out" = "https://storage.example.test/signed/clip.mp4?sig=abc" ] || { printf 'FAIL url printed: %s\n' "$out"; fails=$((fails + 1)); }
contains "url resolves the drive-prefixed path" "$(tail -n 2 "$home/curl-urls.log" | head -n 1)" "/assets/path?drive_id=$drive2&path=%2F$drive2%2FRaw%2FEp%201%2Fclip.mp4"
contains "url signs the asset's original" "$(tail -n 1 "$home/curl-urls.log")" "/assets/cccccccc-cccc-cccc-cccc-cccccccccccc/download?drive_id=$drive2&origin_type=SOURCE&download=true"
check 4 "url of a missing path" "$shade" url "$drive2" /Raw/missing.mp4
contains "missing url names the path" "$err" "Asset not found"

# the key never appears on a command line
lacks "key is absent from every curl argv" "$(cat "$home/curl.log")" "sk_good"
lacks "key is absent from every rclone argv" "$(grep '^argv:' "$home/rclone.log")" "sk_good"

# a key rclone cannot use is an auth failure (3), not "not found" or a plain error
SHADE_API_KEY=sk_stale check 3 "rclone 401 on ls" "$shade" ls "$drive1" /Project
SHADE_API_KEY=sk_stale check 3 "rclone 401 on upload" "$shade" upload "$drive1" "$home/clip.mp4" /StarZero/other.mp4
contains "rclone 401 names the key source" "$err" "SHADE_API_KEY"

# SHADE_API_KEY takes precedence over the file
SHADE_API_KEY=sk_bad check 3 "SHADE_API_KEY overrides the stored key" "$shade" workspaces
contains "refused key names its source" "$err" "SHADE_API_KEY"

# logout
check 0 "logout" "$shade" logout
[ ! -e "$home/.starzero/shade-credentials" ] || { printf 'FAIL logout left the file\n'; fails=$((fails + 1)); }
check 3 "workspaces after logout" "$shade" workspaces

[ "$fails" -eq 0 ] || { printf '%s check(s) failed\n' "$fails"; exit 1; }
printf 'ok   shade: login, listing, upload, download and url behave offline\n'
