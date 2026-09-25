# Waiting for work to finish

Processing, workflow runs and podcast runs take minutes. The CLI offers a `watch` for each; use it as its own command after the `create`, so an interrupted session loses nothing.

## The loop

- `media watch --library <id> <mediaId>...`: polls every 5 s, gives up after 30 min by default.
- `workflow instance watch <instanceId>`: polls every 30 s, gives up after 30 min by default. Podcast runs are watched with the same command.
- Both are silent until done. `--progress` on an instance watch prints one stderr line per poll (`[m:ss] status  credits N  sessions a/b settled  outputs x/y`); `--events` on a media watch prints one NDJSON status change per line to stderr.
- Set `--timeout` below the limit of the shell you run in; the Bash tool's own timeout is the ceiling, so a long run is several watches in a row.

## Terminal states

| Object | Finished | Still going |
| --- | --- | --- |
| media | `completed`, `errored`, `cancelled` | `empty`, `uploading`, `queued`, `processing` |
| instance | `completed`, `partially-completed`, `failed`, `cancelled` | `queued`, `pending` |

## What the exit code says at the end of a watch

| Exit | Meaning | Next step |
| --- | --- | --- |
| 0 | everything completed | use `next.url` / `next.share` or the media |
| 7 | some media errored, or some branches failed | the view on stdout has the status column or the sessions table with a chat link per branch; report which failed and why before deciding anything |
| 1 | everything failed, or the run was cancelled | report; the view is still on stdout |
| 6 | timeout; the work continues server-side | run the resume command from the hint, which is the same `watch` again |
| 130 | interrupted by the user | the hint prints a resume and a cancel command; the run continues until one is chosen |

A `create` that already returned an instance id has started billing. On 6, 7, 130 or any later error, resume or inspect that instance; starting a second one is a new billed run and needs the user's explicit choice.

## `chat send` waits differently

`chat send` streams the agent's turn instead of polling: it prints text, tool digests and questions as they arrive, with a 60 s idle timeout and a 600 s overall `--timeout`. Exit 6 means the turn is still running; `chat get <chatId>` shows `processing` until it settles, then the transcript. Send the next message only after `processing` is false.
