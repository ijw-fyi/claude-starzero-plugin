---
name: ingest-media
description: 'Gets video or audio into a StarZero library until it is processed and searchable, from local files or from video URLs (YouTube, Google Drive, Frame.io, Facebook): picks or creates the library and folder, dry-runs uploads for dedup and the credit estimate, asks before billing, uploads or imports, then watches processing. Use when the user says "upload these files to StarZero", "add this YouTube link to my library", "import these videos", "is my footage done processing", "create a library", or "make a folder".'
argument-hint: "[files, folder or URLs]"
---

# Ingest media

Gets the media the user names (`$ARGUMENTS`: files, a folder to expand into its video and audio files, or video URLs) into a StarZero library and follows processing until the media is `completed`. A search finds nothing until then, so the job ends with a completion check.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the plugin's StarZero connector offers the same API as tools and carries its own instructions; the commands in this skill apply where a shell exists.
- Exit 3 from any command means the login has expired (browser logins last 5 days), or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Sort the arguments. Local paths become absolute file paths (expand a folder in the shell; `media upload` takes files). An `http(s)` URL is a video URL when the page is one video, and goes to `media import`; a YouTube `watch` link that also carries `list=` is sent as the bare `watch?v=<id>` URL, so the server sees one video and not the list. A playlist, channel or folder page is expanded into its video URLs first: with `yt-dlp` on the machine, `yt-dlp --flat-playlist --print url <url>` prints one video URL per line for a playlist or a channel (a printed line that is itself a list page is listed again; read `yt-dlp --help` when unsure; the plugin installs nothing for this); without it, or for a page it cannot list, ask the user for the video links. Drop a URL whose video already appears in the list under another form, since the server keeps one and fails the other. Show the user the final list and its count before anything is sent, since each URL bills.
2. Pick the library with `starzero library list`. Match the name the user gave; ask when several match or none was given. When the user wants a new one, run `starzero library create --name "<name>"` (`--glossary <word...>` for names the transcriber should know) and take the id from `data`. `--library` is required everywhere; there is no default.
3. Pick the folder, when the user wants one, with `starzero folder list --library <id>`. Folders are paths such as `/raw/interviews`; there are no folder ids. Create a missing one with `starzero folder create --library <id> --path /raw/interviews`; the parent must exist, so create nested paths from the top. Upload and import refuse a folder that does not exist.
4. Plan the files with `starzero media upload --library <id> [--folder /path] --dry-run <files...>`. Nothing is sent. Report: one row per file (`planned`, `already-uploaded` with the existing media id and status, `skipped` as `too-small` or `non-media`), the `warnings` (several streams, more than two audio channels, more than 10 hours), and the plan line `~N credits (M left)`. Without ffprobe the estimate is skipped with a warning; say the upload is unestimated. Exit 5 means the estimate exceeds the credits or storage left; report the numbers and stop, unless the user asks to proceed (section below). URLs have no plan step: the server checks credits and storage when it takes the batch.
5. State the billing, per the section below: one question that covers the files and the URLs together.
6. Send. Files: the same command without `--dry-run` and without `--watch`: `starzero media upload --library <id> [--folder /path] <files...>`. URLs: `starzero media import --library <id> [--folder /path] <url...>`, without `--watch`; the server fetches each video itself, and the command returns once the server has taken them, which takes up to minutes for a long list. For both, `--name "<display name>"` applies to a single file or URL and `--meta key=value` adds metadata; flags go before the files or URLs, because `--meta` takes every value up to the next flag. Read the exit code before the output. Take the new media ids from the rows and the exact `media watch` command from `next.watch`; a job with files and URLs has one per command.
7. Watch with each `next.watch` command, in the background, as `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md` describes (the watch has no limit of its own). Processing takes minutes even for short clips. The watch is silent until done; `--events` prints one status change per line on stderr when the user wants a heartbeat. Exit 6 means processing continues: run the resume command from the hint, which is the same watch again.
8. Confirm with `starzero media list --library <id> [--folder /path] --status completed` and check every new id is present.

## Billing

`media upload` without `--dry-run` and `media import` bill the processing of the new media. Before running either:

1. State the exact command and what it bills. Files: the `~N credits (M left)` line from the dry run, or, when ffprobe was absent, "unestimated" next to `creditsLeft` from `starzero credits`. URLs: the number of videos and "unestimated" next to the balance (the `M left` of the dry run, or `creditsLeft` from `starzero credits` when there was no dry run); the server refuses the whole batch with exit 5 when the balance is short, and bills nothing then.
2. Ask once, in words, and wait for the answer: one question that covers both commands when there are files and URLs, carrying the files, the URLs, the estimate and the balance ("Upload 3 files and import 2 videos to the Interviews library: about 48 credits for the files, the videos unestimated, of 12,400 left. Go ahead?"). The user can waive this question for the session (`credits.md`, "Waiving the question"); the statement in step 1 still comes first. The Bash call's `description` repeats the billing line, for example `Import 2 videos to the Interviews library (unestimated, 12,400 credits left)`.
3. Run each command once, after the yes. Re-running a command after a partial failure is safe and needs no second question: landed files are skipped by fingerprint, and imported videos come back `already-imported`, matched by the platform's video id.

`--skip-credit-check` bypasses the exit 5 refusal on uploads. Offer it only when the user asks to proceed anyway; that is a decision to ask about even when the question is waived. Imports have no such flag: an exit 5 there ends at `starzero credits`.

## Report back

- Library id and name, folder path.
- The per-item rows: outcome, media id, status, file or URL.
- Credits: the estimate before, and what the dry run or `starzero credits` said was left.
- After the watch: which ids are `completed`, which `errored`, with the status column.
- Warnings the CLI printed, in the CLI's words.
- The next step: the media can now be searched with `/starzero:find-moments`.
- Deleting media or a library happens in the StarZero app; the CLI has no delete command.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 5 `REFUSED_CREDITS` / `REFUSED_STORAGE` on a dry run | estimate exceeds the balance or storage limit; nothing sent | report the numbers; `--skip-credit-check` only on the user's request |
| exit 5 on `media import` | the server refused the batch for credits or storage; nothing billed | report; `starzero credits` shows the balance, and there is no bypass |
| warning that ffprobe is missing | estimate and non-media filter skipped | say the upload is unestimated; `/starzero:setup` installs ffprobe |
| rows `skipped` (`too-small`, `non-media`) on upload | under 1 KiB, or no audio and no video stream | report; these files stay out |
| rows `already-uploaded` / `already-imported` | same fingerprint, or the same video by platform id, already in the library | use the printed media id; nothing to send |
| upload or import refuses `--folder` (exit 4) | the path does not exist; every import row prints as `skipped` (`not attempted`), nothing sent | `folder create --path`, then re-run |
| exit 7 `UPLOAD_PARTIAL` | some files landed, some did not | re-run the same upload command; landed files are skipped |
| exit 7 `IMPORT_PARTIAL`, rows `failed` | the server could not resolve those URLs and created no media for them; it gives no reason (a private or removed video, a page that is not one video, or the same video under two URL forms in one call) | relay the CLI's hint; the other rows landed. A list page goes back to step 1 for expansion |
| exit 1 on import, every row `failed` | no URL resolved | relay `message`, `hint` and `requestId`; check the URLs are video pages |
| rows `skipped` (`not attempted`) on import, with the error's own exit code | an error stopped the batch before those URLs were sent; rows above them landed and are billed | fix the cause from the error, then re-run the same command: landed videos come back `already-imported` |
| a `failed` row with a media id, on upload | the server created the record, then the file failed | `media get <id>` first; it may be processing, and a re-run skips it by fingerprint |
| exit 1 on upload | every attempted file failed | relay `message`, `hint` and `requestId` from stderr |
| exit 3 during a batch | the batch aborted on an auth error | log in again (`auth.md`), then re-run the same command |
| `cooldown` events on stderr | a part hit a 500 or 503 and waits 30 s | the upload is working; wait |
| exit 6 on `media watch` | still processing | run the resume command from the hint |
| exit 7 `MEDIA_FAILED` / exit 1 on watch | some or all media `errored` | report which, from the status column; a retry happens in the StarZero app |
| exit 1 `POLL_FAILED` | repeated fetch failures in a row | run the same watch again once the API answers |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/upload.md`: read before the first dry run or import.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before the first billed command.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read before the first watch.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read when choosing library ids and folder paths.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read for the exit code table and the JSON envelope.
