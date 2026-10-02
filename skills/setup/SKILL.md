---
name: setup
description: 'Installs and authenticates the starzero CLI: downloads the pinned binary and ffprobe, logs in through the browser (or an API key), checks the stored credential with auth status, compares its scopes with the jobs the user wants, and shows the credit balance. Use when the user says "set up starzero", "log in to StarZero", "my login expired", "no API key", "how many credits do I have", "which scopes do I need", or after any starzero skill exits 3.'
disable-model-invocation: true
---

# Setup

Installs the pinned `starzero` CLI and ffprobe, logs the user in, then checks that a credential with the right scopes reaches the CLI. Every other skill in this plugin assumes these checks pass.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the user connects StarZero from the plugin's Connectors tab; the connector signs in on its own and nothing below applies.
- With a shell, the plugin's StarZero connector (shown by `/mcp` as `plugin:starzero:starzero`) is not used and can stay disconnected; the CLI login below is the only one this surface needs.
- Exit 3 from any command means the login has expired (browser logins last 5 days), or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Run `starzero --version`. The first run downloads the pinned CLI (the version in `${CLAUDE_PLUGIN_ROOT}/reference/CLI_VERSION`) from GitHub releases, verifies its SHA256 sum, then prints the version. A download failure prints the URL and an "offline?" hint; relay both.
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/ensure-tools ffprobe`. On Linux and Windows this fetches a 100-200 MB LGPL build into the CLI's folder, verified against the publisher's checksums. On macOS it looks on PATH and prints `brew install ffmpeg` when absent, exit 0. ffprobe is optional: it powers the upload credit estimate and the non-media filter. Relay the one-line output.
3. Run `starzero auth status`. Exit 0 shows whose credential is stored, its type, scopes and expiry; relay that and go to step 5. Exit 3 means nothing usable is stored: no login yet, a browser token older than 5 days, or a login made with a CLI before 0.8.0, which kept it in the OS keychain that the CLI no longer reads; go to step 4. Any other exit: relay `hint` from stderr.
4. Log the user in by the procedure in `auth.md`, "Logging in from a skill". Ask nothing about terminals or shells; the user may have never opened one.
   - With a browser on this machine (Claude Code on a desktop, Cowork): say a browser tab will open, run `starzero auth login` in the background, relay the URL from its output when no tab opened, and continue once the command ends. The login page asks for every scope the CLI uses, so one login serves every skill.
   - Without a browser here, or when no tab opened: `starzero auth login --no-browser` prints a URL for the user to open on any device; they paste back the address the login ended on, and `starzero auth login --callback "<address>"` finishes it.
   - An API key when the user has one and prefers it: `starzero auth login --api-key <key>`; the user makes one at https://app.starzero.ai/settings/api-keys with the scopes in `auth.md`. A key typed into the chat stays in this conversation's history; say so once.
   - Cloud sessions: the user sets `STARZERO_API_KEY` in the environment's settings. It takes precedence over every stored credential.
   Then re-run `starzero auth status`.
5. When the credential is an API key: ask which jobs the user plans (upload, search, workflows, podcast clips, chat, sharing renders) and compare its scopes from step 3 with the jobs table in `auth.md`. A missing scope means a new key from the API keys page, since scopes cannot be added to an existing key, or a browser login, which carries them all. A browser token needs no scope check; mention its expiry date from step 3.
6. Smoke test and balance: `starzero credits` (free, needs `billing:read`) shows `creditsLeft`, the plan and the credit notes with their expiries; relay them. `starzero library list` (free, `library:read`) confirms library access.
7. External storage (Shade) is not part of this setup: the storage-providers skill checks its own tools and key with `${CLAUDE_PLUGIN_ROOT}/scripts/shade status` when it is first used, and `reference/providers/shade.md` says how the user installs rclone and stores the Shade key.

## Billing

Nothing in this skill spends credits. `--version`, `--help`, `auth status` and `library list` are free.

## Report back

One line per check: CLI version; ffprobe (installed, found on PATH, or the brew hint); who the credential belongs to, its type and expiry; scopes missing for the jobs named (API keys only); credits left and plan; library access. The report repeats no key, even when the user typed one earlier.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| `starzero --version` fails after `ensure-tools starzero` | download blocked or the release is missing | relay the URL and hint; check network |
| `ensure-tools ffprobe` reports a checksum mismatch twice | the publisher's daily rebuild was mid-swap | run it again later; uploads work without the estimate meanwhile |
| exit 3 `AUTH` on `auth status` | nothing stored, a browser token older than 5 days, or a login from a CLI before 0.8.0 | step 4; a login from before 0.8.0 is done once more |
| `auth login` times out or is aborted | the user did not finish in the browser; nothing was stored | run it again |
| `--callback` says no login is in progress, or the callback did not belong to this attempt | `--no-browser` was not run, ran over an hour ago, or the address is from an older URL | run `--no-browser` again and use its URL |
| exit 3 `AUTH` on `auth login --api-key` | key mistyped or revoked; nothing was stored | new key from the API keys page |
| exit 3 `CREDENTIALS_INSECURE` | credentials file readable by others (macOS and Linux) | `chmod 600 ~/.starzero/credentials` |
| exit 3 on one command while `auth status` passes | the key lacks a scope for that command | new key with the scope |
| `auth logout` warns `STARZERO_API_KEY` is still set | the environment variable keeps overriding the store | the user unsets it in their shell |
| a skill exits 3 days after a working setup | the browser token expired (5 days) | step 4; any skill can run the login itself |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`: read before step 4 and step 5.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code other than 0 or 3 appears.
