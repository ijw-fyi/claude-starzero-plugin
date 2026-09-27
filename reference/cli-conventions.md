# starzero CLI conventions

The CLI documents itself. Discover commands with `--help` instead of guessing flags.

## Finding the right command

- `starzero --help` lists the command groups: `auth`, `credits`, `library`, `folder`, `media`, `search`, `workflow`, `podcast-clips`, `output`, `chat`, `artifact`. `credits` is a single command.
- `starzero <group> --help` lists the commands in a group, for example `starzero media --help`. `workflow` has two sub-groups, `template` and `instance`.
- `starzero <group> <command> --help` shows the flags, their defaults and value ranges, for example `starzero media upload --help`. Read it before the first use of a command in a session; the help is the source of truth for flags, and it matches the installed version even when this plugin is older.
- `--help` and `--version` need no API key and cost nothing.

## Global flags and environment

- The human output is the default and the cheaper one to read: tables with the id in the first column, `warning:` lines, and `hint (label): starzero ...` lines carrying the exact follow-up command. Read it as text. `--json` prints the full `data` object instead and exists for piping into other commands; reach for it only when a value is extracted mechanically (`jq` over ids, `processing` on `chat get`, a template's inputs from `describe`), since it is never smaller than the table and often much larger.
- `--print-traffic` logs request and response bodies to stderr, settings included. Reserve it for debugging a request with the user's agreement, and keep it out of shared transcripts.
- `STARZERO_API_KEY`, `STARZERO_KEYRING`, `STARZERO_CONFIG_DIR`: see `auth.md`.

## Output contract

In human mode the same facts appear as the table, then `warning: ...` lines, then `hint (label): command` lines. With `--json`, success on stdout:

```json
{ "ok": true, "data": <result>, "warnings": ["..."], "next": { "<label>": "starzero ..." } }
```

- `warnings` lists things that happened but did not stop the command. Read it: `instance create` reports "variables were not validated" there, and the run has started anyway.
- `next` holds the exact follow-up commands (`watch`, `url`, `share`). Run those verbatim instead of composing your own.

Error, on stderr:

```json
{ "ok": false, "code": "AUTH", "message": "...", "exitCode": 3, "hint": "...", "httpStatus": 401, "requestId": "..." }
```

- `hint` is the recovery step in the CLI's own words. Relay it.
- `requestId` is what StarZero support needs for an API error. Include it when reporting a failure.

## Exit codes decide, stdout informs

| Code | Meaning | What to do |
| --- | --- | --- |
| 0 | success | continue |
| 1 | runtime or API error | read stderr; a cancelled run also ends here |
| 2 | usage error | fix the flags; `--help` shows the accepted values |
| 3 | login expired (browser tokens last 5 days), no credential, bad credential, or missing scope | log in again (`auth.md`), then re-run |
| 4 | not found | check the id came from a list or view |
| 5 | refused before sending anything (credits, storage, invalid variables) | report the numbers; nothing was billed; `starzero credits` shows the balance |
| 6 | the wait ended early: a watch gave up, or a request went unanswered | run the resume command from the hint; for `output render` the disconnect cancelled the render |
| 7 | partial success; details on stdout | inspect the status column or sessions table; retrying is a separate decision |
| 8 | conflict (local file exists, server conflict) | choose another `--out`, or ask before `--force` |
| 130 | interrupted | the run continues; the hint prints resume and cancel commands |

Read the exit code first. On 1, 6 and 7 the CLI can print a complete `{"ok": true, ...}` view on stdout (the partial result) while stderr carries the `{"ok": false, ...}` error. A parser that trusts `ok` on stdout alone misreports failures.

Usage errors come in two forms: a rejected flag prints a plain `error: ...` line with no JSON, while an invalid value inside a handler (an id of the wrong shape, an empty `--query`) prints the JSON error envelope.

## Two commands behave differently

- `chat send` streams the reply as text and ends with a `[done in m:ss · N tool calls · C credits]` footer; with `--json` it becomes one NDJSON event per tool call plus a summary line, which is more tokens for the same information. Stay in human mode unless piping.
- `media upload --events` and `media watch --events` write NDJSON progress to stderr; `workflow instance watch --progress` writes plain lines to stderr. Stdout stays one document.

## Shapes worth knowing

- Lists: `data` is `{ "items": [...], "total": n, "offset": n, "limit": n, "next": <offset or null> }`. `artifact list` uses a cursor: `{ "items": [...], "next": "<createdAt>:<id>" }`.
- Every 24-character hex id is validated locally before any request; a wrong shape is exit 2.
- `--force` means overwrite a local file on `media download` and `media thumbnail`, and skip variable validation on `workflow instance create`. Decide it per command.
- `--library` is required wherever it appears; there is no default library. List libraries or ask before choosing.
- The CLI has no delete commands. Deleting a library, media item, chat or run happens in the StarZero app; say so when asked.
- Human tables put the id in the first column, print sizes in MB, durations as `m:ss`, timestamps as ISO-8601.

## Key hygiene

Reference the key only as the CLI reads it (its store or `STARZERO_API_KEY`). `auth status` is the one way to inspect it, and it prints the scopes and the source while keeping the key itself out of the output.
