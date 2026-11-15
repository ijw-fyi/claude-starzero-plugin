---
name: setup
description: 'Installs and authenticates the starzero CLI: downloads the pinned binary, asks for ffprobe as an optional install, logs in through the browser (or an API key), checks the stored credential with auth status, compares its scopes with the jobs the user wants, and shows the credit balance. Use when the user says "set up starzero", "log in to StarZero", "my login expired", "no API key", "how many credits do I have", "which scopes do I need", or after any starzero skill exits 3.'
disable-model-invocation: true
---

# Setup

Installs the pinned `starzero` CLI, asks for ffprobe, logs the user in, then checks that a credential with the right scopes reaches the CLI. Every other skill in this plugin assumes these checks pass.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `$HOME/.starzero/bin/0.18.0/starzero ...` (`starzero.exe` on Windows); nothing is on PATH. When that file is missing, install it with the commands in `${CLAUDE_PLUGIN_ROOT}/reference/install.md`. Without a shell (claude.ai chat), the user connects StarZero from the plugin's Connectors tab; the connector signs in on its own and nothing below applies.
- With a shell, the plugin's StarZero connector (shown by `/mcp` as `plugin:starzero:starzero`) is not used and can stay disconnected; the CLI login below is the only one this surface needs.
- Exit 3 from any command means the browser login was revoked or comes from a CLI before 0.16.0, or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Run `starzero --version`. When the file is missing, install it with the commands in `${CLAUDE_PLUGIN_ROOT}/reference/install.md` (the release asset for this machine, checked against the release's `SHA256SUMS`), which end by printing the version. A failed step names the URL or the file; relay it with the error.
2. Run `command -v ffprobe`. When it finds nothing, ask the user to install it, with the line for their system from the ffprobe table in `install.md`, and say it is optional: it powers the upload credit estimate and the non-media filter, and everything else works without it. Carry on either way.
3. Run `starzero auth status`. Exit 0 shows whose credential is stored, its type, scopes, expiry and whether it renews; relay who it is, the type and whether it renews, and go to step 5. Exit 3 means nothing usable is stored: no login yet, a browser login made with a CLI before 0.16.0, or one revoked on the server; go to step 4. Any other exit: relay `hint` from stderr.
4. Log the user in by the procedure in `auth.md`, "Logging in from a skill". Ask nothing about terminals or shells; the user may have never opened one.
   - With a browser on this machine (Claude Code on a desktop, Cowork): say a browser tab will open, run `starzero auth login` in the background, relay the URL from its output when no tab opened, and continue once the command ends. The login page asks for every scope the CLI uses, so one login serves every skill.
   - Without a browser here, or when no tab opened: `starzero auth login --no-browser` prints a URL for the user to open on any device; the page they log in on shows a sign-in code; they paste it back, and `starzero auth login --code "<code>"` finishes it.
   - An API key when the user has one and prefers it: `starzero auth login --api-key <key>`; the user makes one at https://app.starzero.ai/settings/api-keys with the scopes in `auth.md`. A key typed into the chat stays in this conversation's history; say so once.
   - Cloud sessions: the user sets `STARZERO_API_KEY` in the environment's settings. It takes precedence over every stored credential.
   Then re-run `starzero auth status`.
5. When the credential is an API key: ask which jobs the user plans (upload, search, workflows, podcast clips, chat, sharing renders) and compare its scopes from step 3 with the jobs table in `auth.md`. A missing scope means a new key from the API keys page, since scopes cannot be added to an existing key, or a browser login, which carries them all. A browser login needs no scope check, and it renews itself, so its `expires` date needs no mention.
6. Smoke test and balance: `starzero credits` (free, needs `billing:read`) shows `creditsLeft`, the plan and the credit notes with their expiries; relay them. `starzero library list` (free, `library:read`) confirms library access.

## Billing

Nothing in this skill spends credits. `--version`, `--help`, `auth status` and `library list` are free.

## Report back

One line per check: CLI version; ffprobe (found on PATH, or the install line shown); who the credential belongs to, its type and whether it renews; scopes missing for the jobs named (API keys only); credits left and plan; library access. The report repeats no key, even when the user typed one earlier.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| the install commands fail | download blocked, the release missing, or a checksum that did not match; nothing was installed | relay the URL and the error; check the network, then run them again |
| exit 3 `AUTH` "Not logged in" on `auth status` | nothing stored, or a browser login from a CLI before 0.16.0 | step 4; a login from before 0.16.0 is done once more |
| `auth login` times out or is aborted | the user did not finish in the browser; nothing was stored | run it again |
| `--code` says no login is in progress, or is not a sign-in code, or `PENDING_LOGIN_UNREADABLE`, or `Login failed` | `--no-browser` was not run, or ran with a CLI before 0.18.0; something other than the code was pasted; or the code was already used, is older than ten minutes, came from an earlier attempt, or `--no-browser` ran over an hour ago | run `--no-browser` again and use the code its page shows |
| exit 3 `AUTH` on `auth login --api-key` | key mistyped or revoked; nothing was stored | new key from the API keys page |
| exit 3 `CREDENTIALS_INSECURE` | credentials file readable by others (macOS and Linux) | `chmod 600 ~/.starzero/credentials` |
| exit 3 on one command while `auth status` passes | the key lacks a scope for that command | new key with the scope |
| exit 3 "needs scopes the login lacks" on every command while `auth status` passes | this CLI needs a scope the browser login was not granted | step 4 |
| `auth logout` warns `STARZERO_API_KEY` is still set | the environment variable keeps overriding the store | the user unsets it in their shell |
| "This login was revoked on the server." | `auth logout` on a machine sharing the login, a copy of the credentials file used elsewhere, or a renewal whose answer got lost | step 4; any skill can run the login itself. A login belongs to one machine, so each machine logs in or shares an API key |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/install.md`: read in step 1 when the CLI is missing, and in step 2 for the ffprobe line.
- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`: read before step 4 and step 5.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code other than 0 or 3 appears.
