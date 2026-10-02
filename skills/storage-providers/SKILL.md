---
name: storage-providers
description: 'Moves files between a StarZero library and an external storage provider, starting with Shade: lists drives and folders, uploads a render or original into a drive, and brings a drive file into a library for processing. Use when the user says "upload this render to Shade", "put the output in our Shade drive", "list my Shade drives", "pull this clip from Shade into StarZero" or "send the video to storage".'
argument-hint: "[provider, drive or path]"
---

# External storage providers

Moves files between StarZero and a storage provider the user already has, in either direction: a StarZero render or original lands in a provider's drive, or a file from a drive enters a StarZero library, by a signed URL the StarZero server fetches itself, or through the normal upload path. Argument: `$ARGUMENTS` names the provider, a drive, or a path on it.

One provider today: **Shade** (shade.inc), through `${CLAUDE_PLUGIN_ROOT}/scripts/shade` and the reference `${CLAUDE_PLUGIN_ROOT}/reference/providers/shade.md`. For any other provider, say the plugin has no connector for it yet and offer the local-file route: the user downloads or uploads with that provider's own tools, and `/starzero:ingest-media` or `/starzero:share-render` covers the StarZero half.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the plugin's StarZero connector offers the same API as tools and carries its own instructions; the commands in this skill apply where a shell exists. The Shade half needs the shell too: on claude.ai chat, the user's Shade connector covers browsing and download links, and uploads into Shade wait for a session with a shell.
- `shade ...` below is `${CLAUDE_PLUGIN_ROOT}/scripts/shade ...`; in this shell the bare name also resolves, through the PATH entry the plugin's hook adds. The user's own terminal has no such entry, so a command meant for them carries the absolute path (`echo "${CLAUDE_PLUGIN_ROOT}/scripts/shade"` prints it). The script drives rclone and jq, which the user installs; the plugin downloads nothing for this. Its exit codes follow the CLI table in `cli-conventions.md`: 2 usage, 3 key missing or refused, 4 not found, 8 destination exists, 1 anything else.
- Exit 3 has two owners here, and each message says which tool it came from. From `starzero`: the StarZero login expired or is missing; log in again by `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"). From `shade`: the Shade key is missing or refused; follow "The key" in `shade.md`.
- Shell variables such as `$dir` below live only inside one Bash call: chain the commands of a step in one call, or substitute the printed path in the next call.

## Steps

1. Check the provider once per session with `shade status`. It prints one line per check (rclone and its version, jq, the key, the workspaces the key sees) and the one thing missing with its fix. rclone missing or older than 1.73, or jq missing: relay the install hint; the user installs them (`shade.md`, "Tools the user installs"). Key missing: the user mints one in Shade under Settings > API Keys and stores it by the procedure in `shade.md` ("The key"); give them the absolute path of the script, and keep the key itself out of the chat.
2. Pick the drive with `shade drives` (one workspace: `--workspace <id>` from `shade workspaces`). Match the name the user gave; ask when several match or none was given. Drive ids are UUIDs from this listing. `shade ls <drive> /path` shows a folder (`size  name` per entry, folders end with `/`); paths are drive-relative and start with `/`.
3. **StarZero to the provider.** Locate the render id the way `/starzero:share-render` does (an instance view's `outputs[].renderId`, or `chat renders <chatId>`; ask when several renders fit the description), then in one Bash call:
   - `dir=$(mktemp -d)`.
   - A render: `starzero output url <renderId>` prints `url` (its `file` field says `video` or `thumbnail`, which one the URL serves); then `curl -fsSL -o "$dir/<renderId>.mp4" "<url>"`. An original instead: `starzero media download --library <id> <mediaId> --out "$dir/<name>"`, where `<name>` is the original filename from `media get`. `output url`, the download and `media download` are free.
   - `shade upload <drive> "$dir/<file>" <dest-path>`. The destination folder is the one the user named; when none was named, ask once, offering the drive root. The destination is `/<folder>/<file>`, or `/<file>` at the root; the file name defaults to `<renderId>.mp4` for a render and to the original filename for a media download, and a path the user gave wins. Folders on the drive are created as needed. A long transfer runs in the background, as `waiting.md` describes for watches; the script is quiet until its result line.
   - Exit 8 means the path exists on the drive: ask before re-running with `--force`, which replaces that file for good. Exit 0 prints `uploaded <bytes> <path>` after a size check against the drive; then `rm -rf "$dir"`. On any failure the local file stays in `$dir`; report that path so a re-run skips the download.
4. **The provider to StarZero.** Two routes; the first is the faster one and the default.
   - Default, the signed URL: `shade url <drive> /path` prints a signed download URL, and `starzero media import --library <id> "<url>"` has the StarZero server fetch the file straight from Shade's storage. Nothing passes through this machine, so the transfer runs at server speed and needs no local disk; a download followed by an upload moves the same bytes twice through the local link. The import follows the import rules in `ingest-media` (unestimated, the billing question, no `--dry-run`). The URL is valid for one day: run the import right after. Import matches repeats by the platform's video id, which a signed URL lacks, so the same file imported twice lands twice; `media list` on the library tells whether it is already there. A row that comes back `failed` sends that file through the fallback.
   - Fallback, download then upload: `shade download <drive> /path "$dir/<name>"` into a `mktemp -d` folder, then `/starzero:ingest-media` from its `--dry-run` step onward (library and folder choice, the plan with the credit estimate, the billing question, `media upload`, `media watch`). Use it when an import row failed, or when the user wants the credit estimate or the content-fingerprint dedup that only the upload path offers. Remove `$dir` once the media status is `completed`.
5. Report, per the section below.

## Before anything moves

Uploads into the provider and downloads from it proceed on the user's request; the one confirmation is before `--force` on an existing destination, since the replaced file is gone from the drive. (Re-running `upload --force` after a size mismatch needs no confirmation: the file being replaced is the one this job just wrote.) Questions that gather an input, such as which drive or which folder, are not confirmations. The StarZero half keeps its own rules: `media upload` and `media import` bill, so the billing question from `credits.md` comes before them, as in `ingest-media`; `output url` and `media download` are free.

## Report back

- The drive (id and name) and the path on it, as `shade` printed them, with the byte count.
- Outbound: which render or media the file came from, and that the temporary folder was removed (or where the file still is).
- Inbound: the new media ids and their status, from the ingest steps; which route carried each file, and why an import fell back to a download when it did.
- Warnings the scripts printed, in their words. Deleting or trashing a file on the drive happens in the Shade app, or through the user's Shade connector when they have it connected; the script has no delete.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| `shade` exit 3 | no Shade key, or Shade refused it (401/403); the message says whether it came from `SHADE_API_KEY` or the stored file | the key procedure in `shade.md`; a refused key is replaced with a new one |
| `shade` exit 1 "rclone 1.73 or newer is required" or "jq is required" | the tool is missing or the distro package is too old | relay the install hint; the user installs, then `shade status` again |
| `shade` exit 8 on `upload` | the drive path exists, or names a folder | ask about `--force`, or choose another name; a folder path needs the file name appended |
| `shade` exit 8 on `download` | the local path exists | another local path, or `--force` on the user's say-so |
| `shade` exit 4 on `ls`, `download`, `url` or `drives --workspace` | the drive path does not exist, or the workspace id is unknown to this key | `shade ls` on the parent, or `shade drives` |
| "size mismatch after upload" | the drive reports a different size than the local file | run the same `upload --force` once more; when it repeats, the user checks the file in the Shade app |
| `curl` on the StarZero URL fails with 403 | the signed URL expired (1 day by default, `renders.md`) | `starzero output url` again and retry the download |
| `media import` row `failed` on a Shade URL | the server could not fetch it (expired URL, or a URL form it does not take) | the fallback: `shade download`, then the upload path, for that file |
| `starzero` exit 3 | the StarZero login expired or is missing | log in again (`auth.md`), then re-run |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/providers/shade.md`: read before the first `shade` command in a session; tools, the key, paths, each subcommand, and what the script leaves to the Shade app.
- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before `output url`; the `url` field and the expiry.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read before the first long transfer; how to run a quiet command in the background.
- `${CLAUDE_PLUGIN_ROOT}/reference/upload.md` and `credits.md`: read before the inbound upload or import, through `ingest-media`.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read for the exit code table both scripts follow.
