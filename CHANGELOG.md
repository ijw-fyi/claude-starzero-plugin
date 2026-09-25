# Changelog

## 0.2.0

- CLI pinned at 0.5.1: `starzero credits` for the balance, plan and credit notes; `output render`
  for temporary renders of search moments; `chat send` waits for the whole turn.
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
