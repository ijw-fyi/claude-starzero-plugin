---
name: podcast-clips
description: 'Cuts one processed StarZero media item into short social clips. Sets clip count, length, aspect, pacing, captions and music with the user (or --auto), confirms billing, starts the podcast-clips run, watches it and returns the clip render ids and links. Use when the user says "make clips from this podcast", "cut this into shorts", "vertical clips for TikTok" or "reels from this interview".'
argument-hint: "[media id]"
---

# Podcast clips

Starts one podcast-clips run on a single processed media item, waits for it, and hands back the clip render ids and links. A podcast run is a workflow instance: the create command is its own, everything after it uses `workflow instance`.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the login has expired (browser logins last 5 days), or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Pick the library. `--library` is required and there is no default: run `starzero library list` and ask when more than one fits. Every id comes from a list or view in this session.
2. Confirm the source is processed. With `$ARGUMENTS` as the media id, run `starzero media get --library <libraryId> <mediaId>` and check `status` is `completed`. Without an id, run `starzero media list --library <libraryId> --status completed` and let the user choose one item. A media item still `processing` has no transcript yet; finish that with `/starzero:ingest-media` first.
3. Check for an active run before starting one. Runs draw on the shared credit balance as they go, so two runs in flight can both fail from credit exhaustion where one alone would have finished, and spent credits stay spent. Workflow template runs count as much as podcast runs, since a podcast run is a workflow instance. Run `starzero workflow instance list --status queued` and `starzero workflow instance list --status pending`; any row means a run is active. Finish it first: watch it to completion with `starzero workflow instance watch <instanceId>` (or let the user cancel it), then start the new one. Several clips come from one run; a second run is for a second media item, after the first run is done. When the user insists on a parallel run, say what can happen and go with their answer.
4. Build the option set with the user, or use `--auto` to let the agent choose the clip count, duration and pacing (`--clips`, `--duration` and `--pacing` are then ignored with a warning). The options: `--clips <n>` (1-20), `--duration <length>` (a preset or minutes per clip), `--aspect <ratio>`, `--pacing <pacing>`, `--music`, `--remove-disfluencies`, `--title-caption`, `--no-stacking`, `--no-transcript-corrections`, `--instructions <text>`, `--name <name>`. Run `starzero podcast-clips create --help` for the defaults, the accepted values and the caption types: the list of `--caption` styles is printed at the end of that help and lives only there, so read it there when the user wants a caption style instead of the default. For a style the list lacks, pass `--caption-preset <id>` with `--caption-style <name>`, optionally `--caption-params <file>`; `--no-captions` renders without captions and excludes every other caption flag.
5. State the billing (next section), then start the run once: `starzero podcast-clips create --library <libraryId> --media <mediaId> [options]`, without `--watch`. Read the exit code first. The output is the workflow instance view plus an `options` block and `next.watch`; the instance id in it is what every later command takes.
6. Watch as a separate command. Read `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md` before the first watch. Run the `next.watch` command, `starzero workflow instance watch <instanceId> --timeout <seconds>`, with `--timeout` below the Bash tool's limit (at most 600 s); a long run is several watches in a row, each started with the resume command the CLI printed on exit 6. Add `--progress` when the user wants one status line per poll on stderr.
7. Final view: `starzero workflow instance get <instanceId>`. Read `${CLAUDE_PLUGIN_ROOT}/reference/renders.md` before handing back links, then run the `next.url` or `next.share` command as printed, or hand over to `/starzero:share-render`.
8. On the user's request only: `starzero workflow instance cancel <instanceId>` stops a run; credits already spent stay spent. `starzero podcast-clips list` answers "how did my clips run go"; older rows show dashes where no options were stored.

See `starzero podcast-clips create --help` and `starzero workflow instance <command> --help` for the rest of the flags.

## Before the create

`podcast-clips create` bills the whole run from the first second and there is no estimate. Read `${CLAUDE_PLUGIN_ROOT}/reference/credits.md` before this step.

1. Run `starzero credits` (free), then say the exact command with the full option set, what it bills ("one clip run on <media name>, N clips of <duration>, <aspect>", or "with --auto, the agent chooses count, duration and pacing") and the balance it draws on (`creditsLeft`). Under 100,000 credits left, add a low-balance warning: runs take a while and can use a large share of it. When step 3 found an active run, say so and offer to wait instead.
2. Ask once, in words, and wait for the answer: one question that carries the command, the billing and the balance ("Cut 6 clips of 45 s, 9:16, from <media name>; the run is billed as it goes, 12,400 credits left. Go ahead?"), with the active-run decision folded in. The user can waive this question for the session (`credits.md`, "Waiving the question"); the statement in step 1 still comes first, and an active run is still asked about. The Bash call's `description` repeats the billing line, for example `Start a podcast-clips run on <media name> (billed run; 12,400 credits left)`.
3. Run it once, after the yes. A create that returned an instance id, timed out or was interrupted has started; resume that instance. A second create is a second bill and is asked about again.

## What to report

From the `get` view: status, `creditsUsed`, the app link as printed, the sessions table with one chat link per branch (a failed branch is diagnosed from its chat link), and `outputs[].renderId` per clip with the `next.url` and `next.share` commands. Pass every link through as the CLI printed it. Deleting a run happens in the StarZero app; the CLI has no delete command.

## Failure modes

| Exit or symptom | Meaning | What to do |
| --- | --- | --- |
| 2 on create | a local option check failed: `--clips` outside 1-20, `--duration` outside the presets or 3-15 minutes, `--no-captions` with a caption flag, `--caption` with `--caption-preset`, or an id of the wrong shape | fix the flags; `--help` shows the accepted values; nothing was billed |
| 1 on create with a 400 naming the preset | the `--caption-preset` and `--caption-style` pair is unknown to the server | pick a style from the `--help` list or a preset id the user has verified in the app |
| warning: `--clips`, `--duration` or `--pacing` ignored | `--auto` was set | expected; relay it |
| source media not `completed` | the transcript is missing, so there is nothing to cut | wait for processing (`/starzero:ingest-media`) and retry the create afterwards |
| a run already `queued` or `pending` in `instance list` | both would draw on the same balance; a second run risks both | watch the active one to completion first, or let the user cancel it; a parallel start is the user's explicit call |
| 7 `INSTANCE_PARTIAL` on watch | some clips rendered, some branches failed; the view is on stdout | list the failed sessions with their chat links; a rerun is a separate decision for the user |
| 1 `INSTANCE_FAILED` or `INSTANCE_CANCELLED` | everything failed or the run was cancelled | show `error` from the view; a rerun is a new billed run |
| 6 on watch | timeout; the run continues server-side | run the resume command from the hint |
| 130 | interrupted; the run continues | print the resume and cancel commands the CLI gave and let the user choose |
| 4 on `media get` or `instance get` | the id is not in this library or not a known instance | take the id from `media list` or `podcast-clips list` |
| 3 | login expired (5 days), or credential missing, invalid or lacking a scope | log in again (`auth.md`), then re-run |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code or output shape is unclear; exit codes decide, stdout informs.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read before taking a media or render id from the user.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before the first billed command.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read before the first watch.
- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before handing back links.
