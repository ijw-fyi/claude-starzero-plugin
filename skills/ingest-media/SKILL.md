---
name: ingest-media
description: 'Uploads local video or audio into a StarZero library until it is processed and searchable: picks or creates the library and folder, dry-runs for dedup and the credit estimate, asks before billing, uploads, then watches processing. Use when the user says "upload these files to StarZero", "add this recording to my library", "is my footage done processing", "create a library", or "make a folder".'
argument-hint: "[files or folder]"
---

# Ingest media

Uploads the files the user names (`$ARGUMENTS`: files, or a folder to expand into its video and audio files) into a StarZero library and follows processing until the media is `completed`. A search finds nothing until then, so the job ends with a completion check.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. The plugin puts it on PATH; when the bare name is not found, call the launcher by path, `${CLAUDE_PLUGIN_ROOT}/scripts/starzero`, which installs the CLI on first use. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the key is missing, invalid or lacks a scope: stop and ask the user to run `/starzero:setup`.

## Steps

1. Resolve the files to absolute paths. Expand a folder argument in the shell; `media upload` takes files.
2. Pick the library with `starzero library list`. Match the name the user gave; ask when several match or none was given. When the user wants a new one, run `starzero library create --name "<name>"` (`--glossary <word...>` for names the transcriber should know) and take the id from `data`. `--library` is required everywhere; there is no default.
3. Pick the folder, when the user wants one, with `starzero folder list --library <id>`. Folders are paths such as `/raw/interviews`; there are no folder ids. Create a missing one with `starzero folder create --library <id> --path /raw/interviews`; the parent must exist, so create nested paths from the top. Upload refuses a folder that does not exist.
4. Plan with `starzero media upload --library <id> [--folder /path] --dry-run <files...>`. Nothing is sent. Report: one row per file (`planned`, `already-uploaded` with the existing media id and status, `skipped` as `too-small` or `non-media`), the `warnings` (several streams, more than two audio channels, more than 10 hours), and the plan line `~N credits (M left)`. Without ffprobe the estimate is skipped with a warning; say the upload is unestimated. Exit 5 means the estimate exceeds the credits or storage left; report the numbers and stop.
5. State the billing, per the section below.
6. Upload with the same command without `--dry-run` and without `--watch`: `starzero media upload --library <id> [--folder /path] <files...>`. Add `--name "<display name>"` only for a single file, `--meta key=value` for metadata. Read the exit code before the output. Take the new media ids from the rows and the exact `media watch` command from `next.watch`.
7. Watch with the command from `next.watch`, adding `--timeout <seconds>` set below the shell's own limit (`media watch` defaults to 1800 s; the Bash tool's timeout is the ceiling). Processing takes minutes even for short clips. The watch is silent until done; `--events` prints one status change per line on stderr when the user wants a heartbeat. Exit 6 means processing continues: run the resume command from the hint, which is the same watch again.
8. Confirm with `starzero media list --library <id> [--folder /path] --status completed` and check every new id is present.

## Billing

`media upload` without `--dry-run` bills the processing of the new media. Before running it:

1. State the exact command and what it bills: the `~N credits (M left)` line from the dry run, or, when ffprobe was absent, "unestimated" next to `creditsLeft` from `starzero credits`.
2. Run it, with the estimate in the Bash call's `description`, for example `Upload 3 files to the Interviews library (bills ~48 credits, 12,400 left)`. The plugin's permission prompt shows that description, so it is the confirmation; a yes in words on top of it would make the user confirm twice. Ask a question only when there is a decision to make: the prompt is off (the user chose that), or `--skip-credit-check` is on the table.
3. Run it once. Re-running the whole command after a partial failure is safe because landed files are skipped by fingerprint.

`--skip-credit-check` bypasses the exit 5 refusal. Offer it only when the user asks to proceed anyway; that is a decision to ask about in words, and the prompt covers the flag too.

## Report back

- Library id and name, folder path.
- The per-file rows: outcome, media id, status, file.
- Credits: the estimate before, and what the dry run said was left.
- After the watch: which ids are `completed`, which `errored`, with the status column.
- Warnings the CLI printed, in the CLI's words.
- The next step: the media can now be searched with `/starzero:find-moments`.
- Deleting media or a library happens in the StarZero app; the CLI has no delete command.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 5 `REFUSED_CREDITS` / `REFUSED_STORAGE` | estimate exceeds the balance or storage limit; nothing sent | report the numbers; `--skip-credit-check` only on the user's request |
| warning that ffprobe is missing | estimate and non-media filter skipped | say the upload is unestimated; `/starzero:setup` installs ffprobe |
| rows `skipped` (`too-small`, `non-media`) | under 1 KiB, or no audio and no video stream | report; these files stay out |
| rows `already-uploaded` | same fingerprint already in the library | use the printed media id; nothing to upload |
| upload refuses `--folder` | the path does not exist | `folder create --path`, then re-run |
| exit 7 `UPLOAD_PARTIAL` | some files landed, some did not | re-run the same upload command; landed files are skipped |
| exit 1 on upload | every attempted file failed | relay `message`, `hint` and `requestId` from stderr |
| exit 3 during a batch | the batch aborted on an auth error | `/starzero:setup`, then re-run the same command |
| `cooldown` events on stderr | a part hit a 500 or 503 and waits 30 s | the upload is working; wait |
| exit 6 on `media watch` | still processing | run the resume command from the hint |
| exit 7 `MEDIA_FAILED` / exit 1 on watch | some or all media `errored` | report which, from the status column; a retry happens in the StarZero app |
| exit 1 `POLL_FAILED` | repeated fetch failures in a row | run the same watch again once the API answers |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/upload.md`: read before the first dry run.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before the first billed command.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read before the first watch.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read when choosing library ids and folder paths.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read for the exit code table and the JSON envelope.
