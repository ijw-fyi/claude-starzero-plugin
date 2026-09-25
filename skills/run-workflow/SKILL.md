---
name: run-workflow
description: 'Runs an existing StarZero workflow template. Describes it, builds the variables JSON, picks the media, confirms billing, starts and watches the instance, then returns the app link, branch chat links and render ids. Use when the user says "run the workflow", "start an instance of template", "what variables does this template need", "is my run finished" or "cancel the run".'
argument-hint: "[template id or name]"
---

# Run a workflow template

Starts one run of an existing StarZero workflow template on a library or a chosen set of media, waits for it, and hands back the app link, one chat link per branch and the render ids. Template authoring is a different job; this skill runs templates that already exist.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. The plugin puts it on PATH; when the bare name is not found, call the launcher by path, `${CLAUDE_PLUGIN_ROOT}/scripts/starzero`, which installs the CLI on first use. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the key is missing, invalid or lacks a scope: stop and ask the user to run `/starzero:setup`.

## Steps

1. Pick the library. `--library` is required and there is no default: run `starzero library list` and ask when more than one fits. Every id comes from a list or view in this session.
2. Find the template. `starzero workflow template list` shows the templates the key owns plus shared ones remembered from earlier runs. Match `$ARGUMENTS` against it by id or name. When the user pasted an id the list lacks, run `starzero workflow template describe <templateId>`: that validates the id and adds it to the list for next time.
3. Read the inputs. `starzero workflow template describe <templateId> --json` prints the variables the template expects (JSON here, because the exact input names and types go straight into the variables file). Build one JSON object from those inputs and write it to a temporary file, for example `vars.json`. Interview the user per input when its meaning or value is unclear. Inputs marked `inferred: true` are set by later steps and only produce warnings. When `describe` exits 1 on a legacy template, `create` still runs, unvalidated; carry that fact into the consent line.
4. Choose the media. `starzero media list --library <libraryId> --status completed` and take `--media <id...>` from it; omit `--media` to run on the whole library. Count the items: fan-out templates bill per item. Several media go into one instance; one instance per media item is the wrong shape.
5. Check for an active run before starting one. Runs draw on the shared credit balance with no reservation, so two runs in flight can both fail from credit exhaustion where one alone would have finished, and spent credits stay spent. Podcast-clip runs are workflow instances too, so they count. Run `starzero workflow instance list --status queued` and `starzero workflow instance list --status pending`; any row means a run is active. Finish it first: watch it to completion with `starzero workflow instance watch <instanceId>` (or let the user cancel it), then start the new one. When the user insists on a parallel run, say what can happen and go with their answer.
6. State the billing (next section), then start the run once: `starzero workflow instance create --template <templateId> --library <libraryId> [--media <id...>] --variables vars.json [--name <name>]`, without `--watch`. Read the exit code first, then `warnings` (`variables were not validated` means the run started anyway) and `next.watch`.
7. Watch as a separate command. Read `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md` before the first watch. Run the `next.watch` command, `starzero workflow instance watch <instanceId> --timeout <seconds>`, with `--timeout` below the Bash tool's limit (at most 600 s); a long run is several watches in a row, each started with the resume command the CLI printed on exit 6. Add `--progress` when the user wants one status line per poll on stderr.
8. Final view: `starzero workflow instance get <instanceId>`. Read `${CLAUDE_PLUGIN_ROOT}/reference/renders.md` before handing back links, then run the `next.url` or `next.share` command as printed, or hand over to `/starzero:share-render`.
9. On the user's request only: `starzero workflow instance cancel <instanceId>` stops a run; credits already spent stay spent. `starzero workflow instance list --template <templateId> --status <status>` answers "what have I run" and "is my run finished".

See `starzero workflow template <command> --help` and `starzero workflow instance <command> --help` for the rest of the flags.

## Before the create

`workflow instance create` bills the whole run from the first second, per fan-out item, and there is no estimate. Read `${CLAUDE_PLUGIN_ROOT}/reference/credits.md` before this step.

1. Run `starzero credits` (free), then say the exact command, what it bills ("one run of template X on N media items", or "on the whole library, N items") and the balance it draws on (`creditsLeft`). When `describe` failed, say validation was skipped and ask whether to go ahead. When step 5 found an active run, ask whether to wait or go ahead. Those are decisions; their answers belong in what you state here.
2. Run it, with the billing in the Bash call's `description`, for example `Start the highlights workflow on 5 media (billed run; 12,400 credits left)`. The plugin's permission prompt shows that description, so it is the confirmation; a yes in words on top of it would make the user confirm twice. Ask a question only when there is a decision to make: the prompt is off (the user chose that), a run is already active, validation was skipped, or a flag such as `--force` or `--skip-credit-check` is on the table.
3. Run it once. A create that returned an instance id, timed out or was interrupted has started; resume that instance. A second create is a second bill and goes through the prompt again.
4. `--force` skips variable validation. Use it only when the user says the template is known to accept the variables; that is a decision to ask about in words.

## What to report

From the `get` view: status, `creditsUsed`, the app link as printed, the sessions table with one chat link per branch (a failed branch is diagnosed from its chat link), and `outputs[].renderId` with the `next.url` and `next.share` commands. Pass every link through as the CLI printed it. Deleting a run happens in the StarZero app; the CLI has no delete command.

## Failure modes

| Exit or symptom | Meaning | What to do |
| --- | --- | --- |
| a run already `queued` or `pending` in `instance list` | credits are shared and unreserved; a second run risks both | watch the active one to completion first, or let the user cancel it; a parallel start is the user's explicit call |
| 5 `VARIABLES_INVALID` on create | the variables failed validation; nothing was billed | fix the file from the listed problems and ask again; `--force` only when the user says the template accepts them |
| `describe` exits 1 on a legacy template | the backend cannot describe it; create proceeds unvalidated with a warning | say validation was skipped and ask whether to go ahead |
| 4 on describe or get | the id is not a known template or instance | take the id from `template list` or `instance list` |
| 2 | a flag or id shape was rejected, or the `--variables` file is unreadable | fix the flags; `--help` shows the accepted values |
| 7 `INSTANCE_PARTIAL` on watch | some branches failed; the view is on stdout | list the failed sessions with their chat links; a rerun is a separate decision for the user |
| 1 `INSTANCE_FAILED` or `INSTANCE_CANCELLED` | everything failed or the run was cancelled | show `error` from the view; a rerun is a new billed run |
| 6 on watch | timeout; the run continues server-side | run the resume command from the hint |
| 130 | interrupted; the run continues | print the resume and cancel commands the CLI gave and let the user choose |
| `cancel` on an unknown id | exit 1, not 4 | check the id against `instance list` |
| 3 | key missing, invalid or lacks a scope | stop; ask the user to run `/starzero:setup` |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code or output shape is unclear; exit codes decide, stdout informs.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read before taking a template, media or render id from the user.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before the first billed command.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read before the first watch.
- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before handing back links.
