# Waiting for work to finish

Processing, workflow runs and podcast runs take minutes. The CLI offers a `watch` for each; use it as its own command after the `create`, so an interrupted session loses nothing.

## The loop

- `media watch --library <id> <mediaId>...`: polls every 5 s.
- `workflow instance watch <instanceId>`: polls every 30 s. Podcast runs are watched with the same command.
- Neither has a default limit: a watch runs until the server finishes unless `--timeout <seconds>` caps it.
- Both are silent until done. `--progress` on an instance watch prints one stderr line per poll (`[m:ss] status  credits N  sessions a/b settled  outputs x/y`); `--events` on a media watch prints one NDJSON status change per line to stderr.
- Leave `--timeout` off and run the watch in the background where the shell tool offers it: Claude Code's Bash tool does, and moves a foreground command there when its own time is up instead of stopping it, then reports when the command ends. The CLI then ends when the server does. Where background commands end with the turn (headless `claude -p` runs), cap `--timeout` under the tool's limit so the CLI ends the wait with exit 6 and a resume hint; a long run is then several watches in a row.

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

`chat send` streams the agent's turn instead of polling: it prints text, a tool digest every 30 s and questions as they arrive, with a two-minute idle timeout and no overall cap unless `--timeout <seconds>` is given. A turn can take many minutes, so leave the cap off and run the call in the background, reading its output when it ends; `--tools` (every tool call with its arguments) stays off unless a turn needs diagnosing. Exit 6, or a call that ended before the footer, means the turn is still running; `chat get <chatId>` shows `processing` until it settles, then the transcript. Send the next message only after `processing` is false.
