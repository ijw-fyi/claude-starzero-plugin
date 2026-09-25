---
name: find-moments
description: 'Finds moments in a StarZero library: searches transcripts for what was said and visuals for what is on screen, returns time ranges, then pulls out a frame, a signed URL, a download, or one preview video of the hits. Use when the user says "find where they talk about", "search my library for", "which clip shows", "grab a frame at", "download the original", or "compile those moments".'
argument-hint: "[what to look for]"
---

# Find moments

Searches a library for `$ARGUMENTS` in the spoken words or on screen and returns time ranges with media ids. From there it hands over a thumbnail, a link, a file, or a watermarked compilation of the hits.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. The plugin puts it on PATH; when the bare name is not found, call the launcher by path, `${CLAUDE_PLUGIN_ROOT}/scripts/starzero`, which installs the CLI on first use. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the key is missing, invalid or lacks a scope: stop and ask the user to run `/starzero:setup`.

## Steps

1. Pick the library with `starzero library list` unless one was chosen earlier in this session. Ask when several match. `--library` is required on every command below.
2. Scope the media with `starzero media list --library <id> --status completed`. Narrow with `--folder /path` (`--recursive` for subfolders) and `--name <substring>`; page with `--limit` and `--offset`. The command fetches the whole library every time, so filter before paging. Only `completed` media are searchable. Keep the names next to the ids for the report.
3. Search. Run both when the request mixes speech and visuals.
   - Spoken words: `starzero search transcript --library <id> --query "<what was said>" [--media <id...>] [--threshold <0-1>] [--limit <n>]`.
   - On screen: `starzero search visual --library <id> --query "<description>" [--media <id...>] [--limit <n>]`, or `--image <file>` instead of `--query`; exactly one of the two.
   Each hit carries `mediaId` and a time range in seconds. Searches may be metered, cheaply.
4. Hand back the moments: media name, media id, the range in seconds, and the matched text or score. Ask which ones to act on when the user has not said.
5. Deliver what the user asked for, per moment. Ids come from step 2 or step 3, in this session.
   - A frame: `starzero media thumbnail --library <id> --at <seconds> [--height <px>] [--out <path>] <mediaId>`. Default name `<mediaId>-<seconds>s.jpg`.
   - A link: `starzero media url --library <id> [--which original|thumbnail|audio|audio-vocals|audio-background] <mediaId>`. The URL carries no key; pass it through as printed.
   - A file: `starzero media download --library <id> [--which ...] [--out <path>] <mediaId>`. Default name is the original filename in the current directory.
   - One preview video of the hits: `starzero output render --library <id> --clip <mediaId>:<start>-<end> [--clip ...] [--aspect 9:16] [--height <px>] --timeout <seconds>`. Clips play in the order given; seconds take decimals. Watermarked by default and free. The command blocks until the render is done and exit 6 cancels it, so keep compilations short and set `--timeout` below the shell's limit (default 600 s). The result is `url`, `durationSeconds` and `urlExpiresInSeconds`; save it with `curl -o <file> "<url>"` while the URL is valid (about a day). A temporary render has no record: the URL is the whole result, and `output url` and `output share` cannot serve it.
6. `--no-watermark` on `output render` gives a clean render and bills credits: see the section below.

See `starzero <group> <command> --help` for the remaining flags.

## Billing

The only billed command here is `starzero output render ... --no-watermark`: currently 250 credits per rendered minute, and the CLI sends it once, without retry. Before running it:

1. Run `starzero credits` (free), then state the exact command, what it bills ("a clean render of N seconds", N being the summed clip lengths; `durationSeconds` of a watermarked trial is the same number) and `creditsLeft`.
2. Run it, with the billing in the Bash call's `description`, for example `Start the highlights workflow on 5 media (billed run; 12,400 credits left)`. The plugin's permission prompt shows that description, so it is the confirmation; a yes in words on top of it would make the user confirm twice. Ask a question only when there is a decision to make: the prompt is off (the user chose that), a run is already active, validation was skipped, or a flag such as `--force` or `--skip-credit-check` is on the table.
3. Run it once. Exit 6 cancelled it; a second run is a second bill and goes through the prompt again.

Every other command in this skill is free, with the search caveat above.

## Report back

- The moments as a table: media name, media id, start-end in seconds, matched text or score.
- Files written, with their paths.
- URLs exactly as the CLI printed them, with their expiry.
- For a compilation: `durationSeconds`, the URL, its expiry, and the local file if downloaded.
- Deleting media happens in the StarZero app; the CLI has no delete command.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| no hits | media not `completed`, or the query is off | `starzero media get --library <id> <mediaId>` to check status; `/starzero:ingest-media` watches processing; then widen the query or lower `--threshold` |
| exit 2 on `search` | empty `--query`, or `visual` got both or neither of `--query` / `--image` | fix the flags; `--help` lists them |
| exit 2 on any id | the id is not 24-hex | take it from `media list` or a search hit |
| exit 8 `FILE_EXISTS` on `download` / `thumbnail` | the local file exists | choose another `--out`, or ask before `--force` |
| `--which audio-vocals` or `audio-background` fails | speech separation has not been run on this media | use `--which audio` or `original` |
| exit 1 with an API code such as `NO_ACCESS_TO_LIBRARY` | the key cannot see that library; this is an API refusal, not exit 3 | pick a library from `library list` |
| exit 6 on `output render` | the wait ended and the render was cancelled | re-run with fewer clips or a longer `--timeout`; a clean render needs a fresh yes |
| `media list` slow | the whole library is fetched per call | filter with `--folder`, `--name`, `--status` before paging |
| `curl -o` returns 404 or 403 | the signed URL expired | run `media url` or `output render` again |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read before taking an id from anything other than a list or search output.
- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before the first `output render`.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before `--no-watermark`.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read for the exit code table and the JSON envelope.
