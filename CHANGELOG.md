# Changelog

## 0.7.3

- CLI pinned at 0.12.1: `media resolve <url>` lists the videos behind a playlist, channel or
  folder share on the server, without importing or billing, and with `--library` leaves out what
  the library already holds. ingest-media uses it in place of `yt-dlp`, after the library is
  picked, with `--json` and in the background; the plugin no longer runs anything on the user's
  machine to read a list page, and the README says so. A YouTube `watch` link with `list=`
  resolves to the whole playlist, so the skill still sends the bare video URL when the user means
  the one video. The CLI also checks once a day for a newer release and prints one `update:` line
  on stderr until the pin moves; cli-conventions tells Claude to leave the line alone, and the
  README discloses the request, the cache file and the opt-outs.

## 0.7.2

- CLI pinned at 0.11.0: `workflow instance get <id> --library --media` resolves a run's library
  (name, size) and its selected media (name, status, duration, origin) next to the unchanged ids,
  one assets call for the library and one per media; a deleted input is a warning and a
  whole-library run has an empty `media` list. share-render, run-workflow and podcast-clips use it
  for "which media did this run use", not on every view. `media get` and `media list --json` carry
  `origin` (`upload`, or the platform and URL an import came from), which upload.md and
  ingest-media name. `artifact list` no longer fails on an artifact that belongs to the account
  rather than a chat (`chatId` null, `CHAT` column `-`), and human output sets warnings and hints
  off from the result by two blank lines.
- The SessionStart hook speaks every session, not only without a login: with one stored it says
  the starzero CLI is logged in and is the route to StarZero, without one it points at
  `/starzero:setup`, and in both cases it says the bundled StarZero connector is a separate,
  optional route. Claude Code reports that connector as unauthenticated until it is connected, and
  Claude was taking that as StarZero being unavailable and skipping the CLI.

## 0.7.1

- CLI pinned at 0.10.0: `starzero workflow instance share <instanceId>` makes a run's outputs
  public at `https://share.starzero.ai/i/<instanceId>` with no expiry, and `--off` takes the page
  back. Every instance view shows `shared` and `sharePage`, and a finished unshared run with outputs
  carries a `next.shareRun` hint. The share-render skill makes it the route for "share the run" and
  "share the clips" (podcast runs included), keeps `output share` for one render or an expiring
  link, and reports that the page is public until `--off`; run-workflow and podcast-clips hand the
  `next.shareRun` command back with the others. `renders.md`, `ids-and-links.md` and
  `cli-conventions.md` gain the run page.

## 0.7.0

- A `storage-providers` skill moves files between a StarZero library and an external storage
  provider, starting with Shade (shade.inc), in both directions: a render or original goes from
  `output url` or `media download` through a temporary folder into a Shade drive, and a drive file
  comes into a library as a signed URL for `media import`, which the StarZero server fetches
  straight from Shade (the faster route), or through `ingest-media`'s upload path as the fallback. Shade's connector and SDK cannot upload, so the bytes go through rclone's
  native Shade backend and the listing through Shade's REST API.
- `scripts/shade`: `login`, `logout`, `status`, `workspaces`, `drives`, `ls`, `upload`,
  `download`, `url`. The Shade key lives in `~/.starzero/shade-credentials` (0600) or
  `SHADE_API_KEY`, reaches curl through stdin and rclone through the environment, and appears on no
  command line; no `rclone.conf` is read or written. Transfers are verified by size (Shade keeps
  no hashes); an existing destination is refused until `--force`; nothing deletes, trashes or
  syncs. Runs under Git Bash on Windows, where the credentials mode check is skipped as the CLI
  does. Exit codes follow the CLI table, with rclone's own codes mapped so a 3 always means the
  key. `test/shade.sh` runs it offline against fake `curl` and `rclone`; `test/shade-live.sh` is
  the opt-in live run against a real account (a stored key, rclone, jq and the network; CI skips
  it), with `--roundtrip` to download a drive file, re-upload it and compare the bytes.
- The user installs rclone (1.73 or newer) and jq; the plugin downloads nothing for Shade, and
  `shade status` prints the install hint. `reference/providers/shade.md` is the Shade document:
  tools, the key, ids and paths, the subcommands, and what stays in the Shade app. README
  discloses the two Shade hosts, the object-storage host behind Shade's presigned URLs, and the
  credential file.
- The chat skill says what `--content` is for: a handful of named items, up to about ten. A chat
  without it covers the whole library, and a wider selection goes into the brief as a filter
  ("only the customer interviews") rather than as a list of hundreds of media ids.

## 0.6.3

- An edit of a video in a library goes through the chat skill: its description now carries the phrases an
  edit request uses ("trim this to 60 seconds", "make it 9:16", "add captions", "add a
  lower-third") and the skill says why a local tool on a downloaded file is the wrong route (word
  timings, speaker-following reframe, caption presets, the agent's checks). find-moments says its
  render is a preview and its download is for the user's own use.
- Designed graphics are made in the session and placed by the agent: `reference/graphics.md`
  covers the two file forms (SVG with a viewBox and fonts by URL, or an H.264 MP4), one element per
  file under 25 MiB, one `chat send --file` turn with a placement brief that asks the agent to
  place the files as they are. Captions and plain on-screen text stay with the agent.

## 0.6.2

- A SessionStart hook: the plugin's `scripts` folder goes on the PATH of the session's Bash
  commands, so `starzero` typed bare runs the launcher; and when no credential is stored
  (`~/.starzero/credentials` or `STARZERO_API_KEY`), Claude is told at the start of the session to
  run `/starzero:setup` before the first StarZero request. It reads that one fact and nothing
  else, and is silent once logged in. `test/session-start.sh` covers it.
- README: a "Before you start" section, since the directory shows the README as the listing text
  and nothing said an account and a plan with credits come first.

## 0.6.1

- CLI pinned at 0.9.0: `starzero media import` creates media from video URLs (YouTube, Google
  Drive, Frame.io, Facebook and many more); the server fetches the videos. The
  `ingest-media` skill takes URLs next to files: a playlist, channel or folder page is expanded
  into video URLs first (with `yt-dlp` when the machine has it, otherwise by asking), the list and
  its count are shown before anything is sent, and the billing question says the import is
  unestimated, since the server checks credits and storage itself and refuses a batch it cannot
  cover. `upload.md` gains the import section; `credits.md`, `auth.md` and `ids-and-links.md`
  gain the `media import` rows.

## 0.6.0

- CLI pinned at 0.8.0: the credential lives in `~/.starzero/credentials` (mode 0600) on every
  platform; the OS keychain is no longer used, which ends the macOS password prompt on every
  command. A login made with an earlier CLI is not read: the first command that needs the login
  after this update exits 3 and any skill logs you in again, once. The README says how to delete the old
  keychain item by hand.
- The launcher no longer sets `STARZERO_KEYRING`; the CLI ignores it. `KEYCHAIN_UNAVAILABLE` is
  gone from the skills and `auth.md`.
- The marketplace description matches the plugin's, and `scripts/check-versions.sh` checks it.

## 0.5.0

- The StarZero connector, StarZero's remote MCP server at `https://mcp.starzero.ai/mcp`, is
  bundled in `.mcp.json`. It is the route on claude.ai chat, where there is no shell. Routing is by
  surface: with a shell the skills use the CLI and the connector stays disconnected, so each
  session has one login; without one the connector's own instructions carry the procedure. Setup
  says so on both routes.
- Long commands (`chat send`, the watches, `output render`, `auth login`) run in the background,
  with no cap set by the skills.
- CLI pinned at 0.7.0: a crash of the CLI is reported to StarZero's Sentry project with the event
  id printed (README says what is sent and how to turn it off; `cli-conventions.md` carries the
  `reported` and `eventId` fields); the `chat send` footer and JSON summary carry the chat's
  context size after the turn.

## 0.4.1

- Chat skill: what the StarZero agent can make, beyond cuts of library footage: deep analysis
  across a whole library, generated video, animated graphics, voiceover, music, sound effects,
  images, captions and reports, with its limits. Through the CLI these run on a brief alone, since
  chats open with the gated tools pre-approved.

## 0.4.0

- CLI pinned at 0.6.1: `starzero auth login` logs in through the browser and stores a 5-day token
  in the OS credential store; `--no-browser` prints a URL and `--callback` finishes the login on
  machines without a browser; `auth logout` revokes the token.
- Setup logs the user in through the browser on every surface. No key is pasted into the chat and
  no plugin option is asked for; the `api_key` option and the SessionStart hook are gone, so the
  plugin ships no hooks. The skills call the launcher by path.
- Every skill logs in again on exit 3, since a browser token expires; `auth.md` carries the one
  procedure for both routes.
- The launcher selects file mode (`STARZERO_KEYRING=0`) when a credentials file exists, so a login
  on a machine without a keychain is found by every later command.
- README section on what the plugin downloads, runs and contacts.

## 0.3.0

- Confirmation before a billed command is a question in words, which the user can waive for the
  session ("go ahead without asking") or permanently from `CLAUDE.md`. The PreToolUse hook that
  forced a yes/no box on every billed command is gone, and with it the `confirm_billed_commands`
  option; the box had no "always allow" and could not be waived.
- The SessionStart hook is the only hook left: it puts the CLI on PATH and hands over the key.
- CLI pinned at 0.5.3: `media upload` waits for the finish call as long as the server takes, and a
  file that fails after its record was created keeps its media id in the row.

## 0.2.0

- CLI pinned at 0.5.2: `starzero credits` for the balance, plan and credit notes; `output render`
  for temporary renders of search moments; no wait has a default limit.
- One confirmation per billed command, through the permission prompt, with the cost and balance
  in its title. Skills no longer ask in words as well.
- Human CLI output by default; `--json` only where a value is read mechanically.
- Chat skill: one chat per task, the agent fans out over the library itself; `--tools` and
  `--timeout` left off.
- Run skills: one workflow or podcast run at a time, since runs draw on the same balance.
- Setup on Cowork: paste the key in the chat; it is stored in the OS credential store.
- Skills name the launcher path as a fallback when `starzero` is not on PATH.

## 0.1.0

First release, never published.

- Seven skills: `setup`, `ingest-media`, `find-moments`, `run-workflow`, `podcast-clips`, `chat`,
  `share-render`, each driving the `starzero` CLI and citing the shared notes in `reference/`.
- Launcher that installs the pinned CLI (0.5.0) on first use from
  `ijw-fyi/starzero-cli-releases`, verified against its `SHA256SUMS`.
- `ensure-tools ffprobe`: a verified LGPL ffprobe next to the CLI on Linux and Windows; Homebrew
  guidance on macOS.
- SessionStart hook that puts the CLI on PATH and hands the API key option to the CLI.
- PreToolUse hook that asks before commands that spend credits; `confirm_billed_commands` option
  to turn it off.
