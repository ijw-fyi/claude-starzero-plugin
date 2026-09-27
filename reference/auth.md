# Authentication

## Two kinds of credential

| Credential | How it is made | Lifetime | Scopes |
| --- | --- | --- | --- |
| Browser login token | `starzero auth login`: the CLI opens the login page, waits, stores the token | 5 days; log in again after that | everything the CLI uses except deleting |
| API key | created at https://app.starzero.ai/settings/api-keys, stored with `starzero auth login --api-key <key>` (or `--stdin`) | until revoked | the scopes chosen when the key was made |

The browser login is the route everywhere: Claude Code and Cowork alike, with nothing pasted into the chat. On a machine without a browser, `--no-browser` prints the URL for the user to open on any device (a phone will do) and takes the address that page ends on. An API key is for cloud sessions, where `STARZERO_API_KEY` is set outside the plugin, and for users who prefer one.

## Where the CLI finds the credential

In order:

1. `STARZERO_API_KEY` in the environment.
2. The credentials file `$STARZERO_CONFIG_DIR/credentials` (default `~/.starzero/credentials`) when `STARZERO_KEYRING=0` is set.
3. The OS keychain otherwise (Credential Manager on Windows, Keychain on macOS, Secret Service on Linux).

`starzero auth login` stores to the keychain, or to the credentials file with `STARZERO_KEYRING=0`. The plugin's launcher sets `STARZERO_KEYRING=0` on its own when that file exists and the variable is unset, so a login made in file mode is found by every later command. `starzero auth logout` removes the stored credential and revokes a browser token on the server. `starzero auth status` shows whose credential is stored, its type, scopes and expiry; run it once at the start of a job and after any exit 3.

## Logging in from a skill

**With a browser on this machine** (Claude Code on a desktop, Cowork):

1. Tell the user a browser tab will open and that the command waits for them to finish there.
2. Run `starzero auth login` in the background where the shell tool offers it (Claude Code's Bash tool does) and relay the URL from its output right away, for the case where no tab opened.
3. Exit 0 means the token is stored; confirm with `starzero auth status`. A timed-out or aborted call stored nothing; run it again.

**Without a browser on this machine** (containers, remote hosts, a desktop where no tab opened):

1. Run `starzero auth login --no-browser`. It prints the login URL and exits; the half-finished login waits in `~/.starzero/login-pending.json` (owner-only) for up to an hour. Add `STARZERO_KEYRING=0` when the machine has no keychain (`KEYCHAIN_UNAVAILABLE` on an earlier attempt).
2. Give the user the URL to open on any device (a phone will do). The login ends on a page that cannot load, at `http://127.0.0.1:<port>/callback?...`; ask the user to paste that page's full address into the chat.
3. Run `starzero auth login --callback "<the pasted address>"`. Exit 0 means the token is stored; `starzero auth status` confirms it.

The pasted address holds a one-time code that only this pending login can redeem, so it is safe in the chat. "No login in progress" (exit 2) means step 1 has not run or the hour passed; "the callback did not belong to this login attempt" (exit 3) means the address came from an older URL. Either way, start over from step 1.

**API key instead**: `starzero auth login --api-key <key>` verifies the key against the server before storing it. The user makes one at the API keys page with the scopes in the table below. Use it when the user has a key and prefers it, or for a cloud session, where `STARZERO_API_KEY` in the environment is read first.

## Recovering from exit 3

| Symptom | Meaning | Recovery |
| --- | --- | --- |
| `AUTH` "Not logged in" | nothing stored, or a token older than 5 days | log in again, as above |
| `AUTH` on `auth login --api-key` | the key was mistyped or revoked; nothing was stored | new key from https://app.starzero.ai/settings/api-keys |
| `KEYCHAIN_UNAVAILABLE` | no OS keychain reachable (headless Linux, containers, sandboxes) | log in again with `STARZERO_KEYRING=0` set; the launcher then selects the file for every later command |
| `CREDENTIALS_INSECURE` | the credentials file is readable by other users | `chmod 600 ~/.starzero/credentials` |
| `AUTH` on one command while `auth status` works | the credential lacks a scope for that command | a browser login covers every skill; an API key needs a new key with the scope, since scopes cannot be added to an existing one |

## Scopes per job (API keys)

A browser login carries all of these. An API key carries what was chosen when it was made; a missing scope shows up as exit 3 on the command that needs it.

| Job | Scopes |
| --- | --- |
| `auth status` | `profile:read` |
| `credits` | `billing:read` |
| list and inspect libraries, folders, media; thumbnails, URLs, downloads | `library:read` |
| create libraries and folders, move media | `library:write` |
| `media upload` | `library:read`, `library:write`; `billing:read` for the credit estimate |
| `search transcript`, `search visual` | `library:search` |
| `workflow instance create`, `podcast-clips create` | `profile:read`, `billing:read`, `library:read`, `library:search`, `rendering:read`, `rendering:write` |
| `output url`, `output share` | `rendering:read` |
| `chat *`, `artifact *` | any valid credential |

A key for every skill: `profile:read`, `billing:read`, `library:read`, `library:write`, `library:search`, `rendering:read`, `rendering:write`.

## Credential hygiene

The credential stays in the CLI's store or the environment. Skills reach it only through `starzero` commands, keeping it out of output, logs and URLs; `media url` and `output url` exist so links carry no credential. An API key the user typed into the chat stays in that conversation's history; say so once, and point at the API keys page for making a new key and revoking the old one.
