# Authentication

## Where the CLI finds the key

In order:

1. `STARZERO_API_KEY` in the environment.
2. The credentials file `$STARZERO_CONFIG_DIR/credentials` (default `~/.starzero/credentials`) when `STARZERO_KEYRING=0` is set.
3. The OS keychain otherwise.

## How this plugin supplies it

- The plugin's "StarZero API key" option (asked at install, editable from `/config`) is written by the plugin's session hook to the credentials file, and the hook exports `STARZERO_KEYRING=0` for the session. Nothing else is needed on Claude Code.
- While that option is set it owns the file. A user who prefers `starzero auth login` clears the option first.
- The hook exports `STARZERO_KEYRING=0` whenever a credentials file exists, so a plugin session reads that file in preference to the keychain. To go back to the keychain, remove `~/.starzero/credentials` as well.
- Cowork does not prompt for plugin options. There the setup skill asks the user to paste the key in the chat and stores it with `starzero auth login --api-key <key>` (OS keychain, or the credentials file with `STARZERO_KEYRING=0` when no keychain is reachable). The conversation then holds the key; the user is told so once, with the API keys page as the place to revoke it.
- Cloud sessions (claude.ai/code) load no plugins. The README explains `STARZERO_API_KEY` as an environment variable there.

## Checking

`starzero auth status` prints the key's source (`STARZERO_API_KEY` or the store), the user id and the scopes. Run it once at the start of a job that needs the API, and after any exit 3.

## Recovering from exit 3

| Symptom | Meaning | Recovery |
| --- | --- | --- |
| `AUTH` on `auth status` with no key | nothing stored | `/starzero:setup` |
| `AUTH` on `auth login` | the key was mistyped or revoked; nothing was stored | new key from https://app.starzero.ai/settings/api-keys |
| `KEYCHAIN_UNAVAILABLE` | no OS keychain reachable (headless Linux, containers, sandboxes) | `STARZERO_KEYRING=0` with the credentials file, or `STARZERO_API_KEY` |
| `CREDENTIALS_INSECURE` | the credentials file is readable by other users | `chmod 600 ~/.starzero/credentials` |
| `AUTH` on one command while `auth status` works | the key lacks a scope for that command | mint a new key with the scope; scopes cannot be added to an existing key |

## Scopes per job

Inferred from the APIs; a 401 or a code-less 403 is how a missing scope shows up.

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
| `chat *`, `artifact *` | the bearer key; no documented scope |

The plugin's install prompt asks for the full set above so one key serves every skill.

## Key hygiene

The key stays in the CLI's store or the environment. Skills reference it only through `starzero` commands, keeping it out of output, logs and URLs; `media url` and `output url` exist so links carry no key.
