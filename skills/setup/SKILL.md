---
name: setup
description: 'Installs and authenticates the starzero CLI: downloads the pinned binary and ffprobe, checks the API key with auth status without printing it, explains how to supply a key, compares its scopes with the jobs the user wants, and shows the credit balance. Use when the user says "set up starzero", "log in to StarZero", "no API key", "how many credits do I have", "which scopes do I need", or after any starzero skill exits 3.'
disable-model-invocation: true
---

# Setup

Installs the pinned `starzero` CLI and ffprobe, then checks that an API key with the right scopes reaches the CLI. Every other skill in this plugin assumes these checks pass.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. The plugin puts it on PATH; when the bare name is not found, call the launcher by path, `${CLAUDE_PLUGIN_ROOT}/scripts/starzero`, which installs the CLI on first use. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the key is missing, invalid or lacks a scope: stop and ask the user to run `/starzero:setup`.

## Steps

1. Run `starzero --version`. The first run downloads the pinned CLI (the version in `${CLAUDE_PLUGIN_ROOT}/reference/CLI_VERSION`) from GitHub releases, verifies its SHA256 sum, then prints the version. A download failure prints the URL and an "offline?" hint; relay both.
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/ensure-tools ffprobe`. On Linux and Windows this fetches a 100-200 MB LGPL build into the CLI's folder, verified against the publisher's checksums. On macOS it looks on PATH and prints `brew install ffmpeg` when absent, exit 0. ffprobe is optional: it powers the upload credit estimate and the non-media filter. Relay the one-line output.
3. Run `starzero auth status`. Exit 0 prints `{ "source", "userId", "scopes" }`; go to step 5. Exit 3 means no usable key; go to step 4. Any other exit: relay `hint` from stderr.
4. On exit 3, tell the user where a key comes from (https://app.starzero.ai/settings/api-keys, with the scopes listed in `auth.md`), then supply it by the route that fits where they are. Ask nothing about terminals or shells; the user may have never opened one.
   - Claude Code: the plugin's "StarZero API key" option in `/config` is the masked route and the first choice. The plugin's session hook writes it to the CLI's credentials file and exports `STARZERO_KEYRING=0`; the hook runs at session start, so ask the user to run `/clear` or start a new session afterwards, then re-check.
   - Cowork, or Claude Code when the user prefers it: ask the user to paste the key in the chat. Store it with `starzero auth login --api-key <key>` (OS keychain: Credential Manager on Windows, Keychain on macOS, Secret Service on Linux); on `KEYCHAIN_UNAVAILABLE`, run the same command with `STARZERO_KEYRING=0` set, which writes `~/.starzero/credentials`. Then tell the user, once: the key is now stored on this machine and this conversation's history contains it; if that ever worries them, the API keys page is where to create a new key and revoke this one, after which they log in again with the new one.
   - Cloud sessions: the user sets `STARZERO_API_KEY` in the environment's settings. It takes precedence over every stored key.
   Then re-run `starzero auth status`.
   Plugin sessions read the credentials file whenever one exists and the keychain only when there is none; a user switching from the plugin option to a keychain login clears the option and removes `~/.starzero/credentials`.
5. Ask which jobs the user plans (upload, search, workflows, podcast clips, chat, sharing renders) and compare `scopes` from step 3 with the jobs table in `auth.md`. A missing scope means a new key from the API keys page (`starzero auth login --help` prints the URL); scopes cannot be added to an existing key.
6. Smoke test and balance: `starzero credits` (free, needs `billing:read`) shows `creditsLeft`, the plan and the credit notes with their expiries; relay them. `starzero library list` (free, `library:read`) confirms library access.

## Billing

Nothing in this skill spends credits. `--version`, `--help`, `auth status` and `library list` are free.

## Report back

One line per check: CLI version; ffprobe (installed, found on PATH, or the brew hint); key `source` and `userId`; scopes present; scopes missing for the jobs named; credits left and plan; library access. The report repeats the key nowhere, even when the user pasted it earlier.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| `starzero --version` fails after `ensure-tools starzero` | download blocked or the release is missing | relay the URL and hint; check network |
| `ensure-tools ffprobe` reports a checksum mismatch twice | the publisher's daily rebuild was mid-swap | run it again later; uploads work without the estimate meanwhile |
| exit 3 `AUTH` on `auth status` | nothing stored | step 4 |
| exit 3 `AUTH` on `auth login` | key mistyped or revoked; nothing was stored | new key from the API keys page |
| exit 3 `KEYCHAIN_UNAVAILABLE` | no OS keychain (headless Linux, containers, sandboxes) | `STARZERO_KEYRING=0` with the credentials file, or `STARZERO_API_KEY` |
| exit 3 `CREDENTIALS_INSECURE` | credentials file readable by others | `chmod 600 ~/.starzero/credentials` |
| exit 3 on one command while `auth status` passes | the key lacks a scope for that command | new key with the scope |
| `auth logout` warns `STARZERO_API_KEY` is still set | the environment variable keeps overriding the store | the user unsets it in their shell |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`: read before step 4 and step 5.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code other than 0 or 3 appears.
