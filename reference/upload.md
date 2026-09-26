# Uploads

`starzero media upload --library <id> [--folder /path] <files...>` sends local video or audio into a library and returns when the bytes are stored. Processing (transcripts, visual index) continues server-side; `media watch` follows it.

## Before any byte moves

The CLI plans the upload locally and prints the plan with `--dry-run`:

- Files under 1 KiB are skipped as `too-small`.
- With ffprobe present, files with neither an audio nor a video stream are skipped as `non-media`, durations are read, and the credit estimate is computed. Without ffprobe the upload still works; the estimate and the non-media filter are skipped with a warning. The plugin's setup installs ffprobe next to the CLI on Linux and Windows and points macOS users at Homebrew.
- Each file gets a content fingerprint, the same one the web app uses. A media item in the library with the same fingerprint is reported as `already-uploaded` with its id and status instead of being sent again.
- The plan line reads `~N credits (M left)`; exit 5 `REFUSED_CREDITS` or `REFUSED_STORAGE` means nothing was sent.

Flags to know: `--folder` must already exist (`folder create --path ...` first); `--name` applies to a single file; `--meta key=value` repeats; `--watch` also waits for processing, though a separate `media watch` is the safer choice in a session.

## During

64 MiB parts, four parts per file and two files at a time by default (`--parallel-parts`, `--parallel-files`). A part that gets a 500 or 503 waits 30 s before retrying; `--events` shows those as `cooldown` events on stderr, and a slow upload with cooldowns is working, not stuck.

## After

One row per file: `OUTCOME  MEDIA  STATUS  FILE`, with outcomes `uploaded`, `already-uploaded`, `skipped`, `failed`, `planned`. Then a summary and `next.watch` with the exact `media watch` command for the new media ids. Run that command; processing takes minutes even for short clips, and a search finds nothing until the media is `completed`.

Exit 7 `UPLOAD_PARTIAL` means some files landed and some did not. Re-running the same upload command is safe: files that landed are skipped by fingerprint, and the hint says so. Hand-rolled retries of individual parts are not. A `failed` row that still shows a media id (the server created the record before the failure) is checked with `media get <id>` before any re-run: it may be processing. The finish call waits as long as the server takes, so a slow finish is a working upload.

Warnings worth relaying: several video or audio streams, more than two audio channels, more than 10 hours (the API rejects those).
