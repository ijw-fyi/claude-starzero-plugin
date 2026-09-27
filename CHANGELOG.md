# Changelog

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
