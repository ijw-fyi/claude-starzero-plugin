# Installing the CLI

The plugin ships no program. The `starzero` CLI is one binary published at https://github.com/ijw-fyi/starzero-cli-releases, and the skill that needs it installs it into the user's config folder with the commands below. The pinned version is 0.18.0.

## Where it lives

`$HOME/.starzero/bin/0.18.0/starzero` (`starzero.exe` on Windows); `$STARZERO_CONFIG_DIR` replaces `$HOME/.starzero` when it is set. Nothing puts it on PATH, so every command runs it by that path, and a `starzero` found elsewhere on the machine is another install, not the plugin's. The file being there means it is installed. A version folder left by an earlier plugin stays until the user deletes it.

## Install

Run this when the file is missing. It picks the release asset for this machine, checks it against the release's `SHA256SUMS`, unpacks it into the version folder, and prints the version. Nothing is installed when a step fails, and the failing step names the URL or the file; relay that with the error.

```sh
v=0.18.0; base="https://github.com/ijw-fyi/starzero-cli-releases/releases/download/v$v"
dir="${STARZERO_CONFIG_DIR:-$HOME/.starzero}/bin/$v"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) asset=starzero-linux-x64.tar.gz ;;
  Linux-aarch64|Linux-arm64) asset=starzero-linux-arm64.tar.gz ;;
  Darwin-arm64) asset=starzero-darwin-arm64.tar.gz ;;
  MINGW*|MSYS*|CYGWIN*) asset=starzero-windows-x64.zip ;;
  *) echo "starzero has no build for $(uname -s)-$(uname -m)"; false ;;
esac \
&& tmp=$(mktemp -d) \
&& curl -fsSL --retry 3 -o "$tmp/$asset" "$base/$asset" \
&& curl -fsSL --retry 3 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" \
&& (cd "$tmp" && grep " $asset\$" SHA256SUMS | { command -v sha256sum >/dev/null && sha256sum -c - || shasum -a 256 -c -; }) \
&& mkdir -p "$dir" \
&& case "$asset" in *.zip) unzip -qo "$tmp/$asset" -d "$dir" || tar -xf "$tmp/$asset" -C "$dir" ;; *) tar -xzf "$tmp/$asset" -C "$dir" ;; esac \
&& chmod +x "$dir"/starzero* && rm -rf "$tmp" && "$dir/starzero" --version
```

The download is the CLI's own release, about 40 MB, from GitHub; the checksum file sits next to it in the same release. Windows runs this in Git Bash, where `unzip` may be absent and `tar` unpacks the zip instead.

## ffprobe

Optional. It powers the upload credit estimate and the non-media filter in `media upload`, and checks a graphic rendered as MP4; everything else works without it. The CLI looks for `ffprobe` next to its own binary first, then on PATH. When `command -v ffprobe` finds nothing, tell the user once, with the line for their system, and carry on:

| System | Install |
| --- | --- |
| macOS | `brew install ffmpeg` |
| Debian, Ubuntu | `sudo apt install ffmpeg` |
| Fedora | `sudo dnf install ffmpeg` |
| Windows | `winget install Gyan.FFmpeg` |
