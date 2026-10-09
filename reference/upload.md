# Uploads and imports

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

## From URLs (`media import`)

`starzero media import --library <id> [--folder /path] <url...>` creates one media per video URL (YouTube, Google Drive, Box, Frame.io, Shade, Facebook and many more) or per direct file URL (an `https` link whose body is the video file, such as the signed URL `shade url` prints for a Shade drive file); the server fetches the video itself, so no bytes leave the machine. It returns once the server has taken the videos, which takes up to minutes for a long list; processing then continues as after an upload, and `next.watch` carries the same `media watch` command. `--folder`, `--name` (single URL), `--meta`, `--watch` and `--events` work as on `media upload`.

What differs from an upload:

- One URL is one video. A playlist, channel or folder page is turned into video URLs first with `media resolve` (below); sent to `media import` as it is, it comes back `failed`, with a hint that names `media resolve`.
- There is no plan step, no `--dry-run` and no `--skip-credit-check`: the server checks credits and storage when it takes a batch and refuses the whole batch with exit 5, billing nothing.
- Repeats are matched by the platform's video id rather than a content fingerprint: a video the library already holds comes back `already-imported` with its id, so re-running the command is safe. The same video under two URL forms in one call lands once; the second form is a `failed` row.
- URLs go to the server in batches of 100, in input order. An error on a later batch leaves the earlier ones imported and billed; the URLs never sent print as `skipped` (`not attempted`) under the rows that landed, and the command exits with that error.
- A `failed` row carries no reason from the server. The hint names the likely ones (a private or removed video, a page that is not one video, a duplicate URL form); the row is relayed with that hint, and nothing else is invented.

Rows: `OUTCOME  MEDIA  STATUS  URL`, outcomes `imported`, `already-imported`, `failed`, `skipped`, then a summary line. Afterwards `media get` and `media list --json` carry `origin`: in human output `upload` for a file, or the platform and the URL as it was sent (`youtube https://...`) for an import; in JSON `{ "source": "user", "type": "upload" }` or `{ "source": "external", "type": "<platform>", "id": "<the platform's video id>", "url": "..." }`. So where a media came from can be told from the library later. Exit 7 `IMPORT_PARTIAL` means some URLs failed and the rest landed; exit 1 means every URL failed.

## Listing a page first (`media resolve`)

`starzero media resolve [--library <id>] <url>` lists the videos behind a video, playlist, channel or folder share without importing any and without spending credits: one row per video with `url`, `platform`, `id` (the platform's video id, what `origin` stores after an import), `title`, `duration` in seconds and `path` for a folder share; `--json` keeps the provider's other columns under `extra`. A YouTube `watch` link with `list=` lists the whole playlist. With `--library`, the videos the library already holds are left out (`--all` lists them with their media id), `alreadyImported` counts them, and `next.import` is the `media import` command for the rest, cut to 10 URLs. Listing a channel or a large folder takes the server minutes. Exit 6 means the call ended while the server was still listing: the rows so far are on stdout with the warning `the list is incomplete`, and a new call starts from scratch. Exit 1 means no video was found behind the URL.
