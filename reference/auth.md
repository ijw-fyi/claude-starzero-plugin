# Authentication

## Two kinds of credential

| Credential | How it is made | Lifetime | Scopes |
| --- | --- | --- | --- |
| Browser login | `starzero auth login`: the CLI opens the login page, waits, stores the login | renews itself as commands run, with no routine log-in; ends with `auth logout` or a revocation on the server | everything the CLI uses except deleting |
| API key | created at https://app.starzero.ai/settings/api-keys, stored with `starzero auth login --api-key <key>` (or `--stdin`) | until revoked | the scopes chosen when the key was made |

The browser login is the route everywhere: Claude Code and Cowork alike, with nothing pasted into the chat. On a machine without a browser, `--no-browser` prints the URL for the user to open on any device (a phone will do) and takes the address that page ends on. An API key is for cloud sessions, where `STARZERO_API_KEY` is set outside the plugin, and for users who prefer one.

A browser login belongs to one machine. A copy of the credentials file used elsewhere gets the login revoked on both at the next renewal, so each machine logs in for itself, or an API key shares the access. Two machines logged in from one browser can share a login, and `auth logout` on one ends both.

## Where the CLI finds the credential

In order:

1. `STARZERO_API_KEY` in the environment.
2. The credentials file `$STARZERO_CONFIG_DIR/credentials` (default `~/.starzero/credentials`), on every platform.

`starzero auth login` writes that file (one line, owner-only, mode 0600). On macOS and Linux the CLI refuses to read a file that other users can read (`CREDENTIALS_INSECURE`). CLI versions before 0.8.0 kept the credential in the OS keychain instead, and that item is no longer read. A browser login made with any CLI before 0.16.0 is "Not logged in" once, and the user logs in again; a stored API key carries over. `starzero auth logout` removes the stored credential and ends a browser login on the server, a chat turn running on it included, so it runs only when the user asks. A warning that the revocation failed means the login stays valid on the server, and a login from before 0.16.0 is removed from this machine only. `starzero auth status` shows whose credential is stored, its type, scopes, expiry and whether it renews: `expires` is the current token, and a login showing `renews yes` carries on past it. Run it once at the start of a job and after any exit 3.

## Logging in from a skill

**With a browser on this machine** (Claude Code on a desktop, Cowork):

1. Tell the user a browser tab will open, that it asks them to approve access, and that the command waits for them to finish there.
2. Run `starzero auth login` in the background where the shell tool offers it (Claude Code's Bash tool does) and relay the URL from its output right away, for the case where no tab opened.
3. Exit 0 means the token is stored; confirm with `starzero auth status`. A timed-out or aborted call stored nothing; run it again.

**Without a browser on this machine** (containers, remote hosts, a desktop where no tab opened):

1. Run `starzero auth login --no-browser`. It prints the login URL and exits; the half-finished login waits in `~/.starzero/login-pending.json` (owner-only) for up to an hour.
2. Give the user the URL to open on any device (a phone will do). The login ends on a page that cannot load, at `http://127.0.0.1:<port>/callback?...`; ask the user to paste that page's full address into the chat.
3. Run `starzero auth login --callback "<the pasted address>"`. Exit 0 means the token is stored; `starzero auth status` confirms it.

The pasted address holds a one-time code that only this pending login can redeem, so it is safe in the chat. "No login in progress" (exit 2) means step 1 has not run or the hour passed; "the callback did not belong to this login attempt" (exit 3) means the address came from an older URL. Either way, start over from step 1.

**API key instead**: `starzero auth login --api-key <key>` verifies the key against the server before storing it. The user makes one at the API keys page with the scopes in the table below. Use it when the user has a key and prefers it, or for a cloud session, where `STARZERO_API_KEY` in the environment is read first.

## Recovering from exit 3

| Symptom | Meaning | Recovery |
| --- | --- | --- |
| `AUTH` "Not logged in" | nothing stored, or a browser login made with a CLI before 0.16.0 | log in again, as above |
| `AUTH` "This login was revoked on the server." | `auth logout` on a machine sharing the login, a copy of the credentials file used elsewhere, or a renewal whose answer got lost | log in again, as above |
| `AUTH` "needs scopes the login lacks", on every command while `auth status` works | this CLI needs a scope the browser login was not granted | log in again, as above |
| `AUTH` on `auth login --api-key` | the key was mistyped or revoked; nothing was stored | new key from https://app.starzero.ai/settings/api-keys |
| `CREDENTIALS_INSECURE` | the credentials file is readable by other users (checked on macOS and Linux) | `chmod 600 ~/.starzero/credentials` |
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
| `media import` | `library:read`, `library:write` |
| `search transcript`, `search visual` | `library:search` |
| `workflow instance create`, `podcast-clips create` | `profile:read`, `billing:read`, `library:read`, `library:search`, `rendering:read`, `rendering:write` |
| `output url`, `output share` | `rendering:read` |
| `chat *`, `artifact *`, `skill *` | any valid credential |

A key for every skill: `profile:read`, `billing:read`, `library:read`, `library:write`, `library:search`, `rendering:read`, `rendering:write`.

## Credential hygiene

The credential stays in the credentials file or the environment. An API key in that file is a long-lived secret, and so is a browser login, which renews itself; on a shared machine, `STARZERO_API_KEY` set for the session keeps the key out of the file. Skills reach it only through `starzero` commands, keeping it out of output, logs and URLs; `media url` and `output url` exist so links carry no credential. An API key the user typed into the chat stays in that conversation's history; say so once, and point at the API keys page for making a new key and revoking the old one.
