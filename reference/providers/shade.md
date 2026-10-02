# Shade

Shade (shade.inc) is a media asset manager: workspaces hold drives, drives hold folders and files. The plugin reaches it through `${CLAUDE_PLUGIN_ROOT}/scripts/shade`, which uses Shade's REST API (`api.shade.inc`) for listing, the key check and signed URLs, and rclone's native `shade` backend for the bytes (Shade's transfer API at `fs.shade.inc`, then the object-storage host its presigned URLs name). Shade's own connector and SDK browse and sign links but cannot upload, which is why the bytes go through rclone.

## Tools the user installs

The plugin downloads nothing for Shade. `shade status` checks both tools and prints the install hint when one is missing:

- **rclone 1.73 or newer**, the release that added the Shade backend. https://rclone.org/install/ has the one-line installer; `brew install rclone` on macOS. Distribution packages (apt, dnf) are often older than 1.73 and fail the version check; the hint says so.
- **jq**, from the package manager (`brew install jq`, `apt install jq`).

The script runs rclone with its configuration coming from the environment of that one process and `--config` pointing at an empty file, so a user's own `rclone.conf` is neither read nor written, and an encrypted one never prompts for a password.

## Windows

The script is a POSIX shell script and runs under Git Bash, the shell Claude Code uses on Windows; rclone (`rclone.exe`, from rclone.org or `winget install Rclone.Rclone`) and jq (`winget install jqlang.jq`) go on the PATH as on any platform. Two differences: the credentials file's mode check is skipped, since Git Bash emulates permission bits (the starzero CLI skips it there too), and `login --stdin` is typed in a Git Bash window. A user whose terminal is PowerShell saves the key to a file instead, Claude runs `shade login --key-file <path>`, and the user deletes the file.

## The key

A Shade API key is personal: minted in the Shade app under **Settings > API Keys**, it acts as that user and sees every workspace and drive they can. Where the script finds it, in order:

1. `SHADE_API_KEY` in the environment (cloud sessions, or a user who prefers it).
2. `$STARZERO_CONFIG_DIR/shade-credentials` (default `~/.starzero/shade-credentials`), one line, owner-only. The script refuses a file other users can read (`chmod 600` fixes it).

Storing it, with the key kept out of the chat:

- The user runs `<absolute path to>/scripts/shade login --stdin` in their own terminal and pastes the key there. Print the absolute path for them: the plugin's `scripts` folder is on PATH only inside Claude's shell. The script verifies the key with one `GET /workspaces`, stores it, and prints the workspaces it sees.
- A key saved in a file: `shade login --key-file <path>`; delete the file afterwards.
- A key typed into the chat stays in the conversation's history; say so once and point at the API keys page for revoking it and minting another.

`shade logout` removes the stored key (and warns when `SHADE_API_KEY` still overrides). The key travels to curl through a config on stdin and to rclone through the environment, so it appears on no command line and in no output; `status` prints its source, not its value.

## Ids and paths

- `shade workspaces` lists workspaces (id, name, domain); `shade drives` lists every drive the key sees with its workspace, or one workspace's with `--workspace <id>`. Ids are UUIDs and come from these listings in the same session; the drive's settings page in the Shade app shows the same id.
- Paths are drive-relative and start with `/`: `/Project/Ep 1/clip.mp4`. Shade's app and connector show the same paths. The script adds the drive prefix the REST API wants on its own.
- Names on a drive are case-insensitive: `Clip.mp4` and `clip.mp4` are the same file. A name is at most 255 characters.
- `upload` creates missing folders on the drive; there is no separate mkdir.

## Subcommands

| Command | Does | Exit codes beyond 0 |
| --- | --- | --- |
| `login --stdin` / `--key-file <path>` | verifies the key against `/workspaces`, stores it | 2 usage (a key as an argument is refused), 3 refused |
| `logout` | removes the stored key | |
| `status` | rclone version, jq, key source, workspaces seen | 1 tool missing or old, 3 no key or refused |
| `workspaces` | table: id, name, domain | 3 |
| `drives [--workspace <id>]` | table: id, name, workspace | 3, 4 unknown workspace |
| `ls <drive> [path]` | `size  name` per entry, folders end with `/` | 3, 4 folder missing |
| `upload <drive> <file> <dest-path> [--force]` | one file to one path; size check afterwards; prints `uploaded <bytes> <path>` | 2 unreadable or empty file, or a dest-path ending in `/`; 8 destination exists, or is an existing folder; 1 size mismatch or transfer failure |
| `download <drive> <path> <out> [--force]` | one file to one local path; size check; prints `downloaded <bytes> <out>` | 4 missing on the drive, 8 local file exists |
| `url <drive> <path>` | a signed download URL for the file, valid one day | 3, 4 missing, or a folder |

Every command that takes a drive or workspace id exits 2 on anything but a UUID; a well-formed id the key cannot reach comes back as 3 (Shade refused it) or 4 (unknown). rclone's own exit codes are mapped (its 3 and 4, "not found", become 4; a 401 or 403 from Shade becomes 3), so a 3 from this script always concerns the key: missing, refused, or its file readable by other users.

## Transfers

- Shade stores no content hashes, so the script verifies each transfer by size: the drive's size after an upload against the local file, the local size after a download against the drive. A mismatch exits 1 and names both numbers.
- `--force` on `upload` passes `--ignore-times` to rclone, so a same-sized file is replaced too; without it, the script refuses an existing destination with exit 8 before any byte moves. Replacing a file is final: the previous bytes do not go to Shade's trash.
- Multipart, 64 MiB parts, with rclone's own retries; 30 s to connect and 5 minutes of idle time before a request is given up. A long transfer is quiet until its result line, so run it in the background where the shell tool offers it (`waiting.md`), and read the output when it ends.

## What the script leaves to the Shade app

No delete, trash, move or sync: rclone's deletes bypass Shade's trash, so those stay in the Shade app, or in the user's Shade connector when they have it connected (its trash is recoverable). When the user asks for one, say where it happens.

## The signed URL route

`shade url` signs a download URL through Shade's API (the path resolves to an asset, the asset signs a URL for its original bytes), for `starzero media import` to fetch server-side. This is the faster way from Shade into StarZero and the default in the `storage-providers` skill: the StarZero server pulls the bytes straight from Shade's storage, so nothing passes through the local machine and no local disk is needed, where a download followed by an upload moves the same bytes twice over the local link. The link is valid for one day (`X-Amz-Expires=86400` in the URL): run the import right after. Import matches repeats by the platform's video id, which a signed URL lacks, so expect the same file imported twice to land twice. A row that comes back `failed` sends that file through `shade download` and then `ingest-media`'s upload path, which is also the route when the user wants the credit estimate or the content dedup that only the upload offers.

## claude.ai chat

No shell there, so none of this runs. The user's Shade connector (if connected) browses drives and signs download URLs; a Shade URL from it can go to the StarZero connector's import. Uploading into Shade waits for a session with a shell.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 3 "no Shade key" | nothing in `SHADE_API_KEY` or the credentials file | the login procedure above |
| exit 3 "Shade refused the key from ..." | 401 or 403; the key was revoked or mistyped; the message names the source | a new key under Settings > API Keys, then `login --stdin` (or fix `SHADE_API_KEY`) |
| exit 3 "readable by other users" | the credentials file has group or world bits | `chmod 600 ~/.starzero/shade-credentials` |
| exit 1 "rclone 1.73 or newer is required" | missing, or a distro package below 1.73 | install from rclone.org/install or brew |
| exit 1 "could not reach api.shade.inc" | offline, or a proxy | check the network; nothing was changed |
| exit 4 on `ls`, `download` or `url` | the path is not on the drive | `ls` the parent; paths are case-insensitive but spelling counts |
| exit 4 on `drives --workspace` | the key sees no workspace with that id | `shade workspaces` |
| exit 8 on `upload` | the destination exists, or names a folder | ask about `--force`, or append the file name |
| exit 1 "size mismatch" | the drive holds a different size than the local file | `upload --force` once more; then the Shade app |
| exit 1 "unexpected response" on `url` | Shade answered without a URL | relay the body; the download route still works |
