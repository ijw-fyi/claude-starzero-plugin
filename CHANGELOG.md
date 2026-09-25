# Changelog

## 0.1.0

First release.

- Seven skills: `setup`, `ingest-media`, `find-moments`, `run-workflow`, `podcast-clips`, `chat`,
  `share-render`, each driving the `starzero` CLI and citing the shared notes in `reference/`.
- Launcher that installs the pinned CLI (0.5.1) on first use from
  `ijw-fyi/starzero-cli-releases`, verified against its `SHA256SUMS`.
- `ensure-tools ffprobe`: a verified LGPL ffprobe next to the CLI on Linux and Windows; Homebrew
  guidance on macOS.
- SessionStart hook that puts the CLI on PATH and hands the API key option to the CLI.
- PreToolUse hook that asks before commands that spend credits; `confirm_billed_commands` option
  to turn it off.
