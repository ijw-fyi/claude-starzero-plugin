# Waiting for work to finish

Processing, workflow runs and podcast runs take minutes. The CLI offers a `watch` for each; use it as its own command after the `create`, so an interrupted session loses nothing.

## The loop

- `media watch --library <id> <mediaId>...`: polls every 5 s.
- `workflow instance watch <instanceId>`: polls every 30 s. Podcast runs are watched with the same command.
- Neither has a limit of its own: a watch runs until the server finishes.
- Both are silent until done. `--progress` on an instance watch prints one stderr line per poll (`[m:ss] status  credits N  sessions a/b settled  outputs x/y`); `--events` on a media watch prints one NDJSON status change per line to stderr.
- Run the watch in the background where the shell tool offers it (Claude Code's Bash tool does) and read its output when it ends; the CLI ends when the server does. A watch ended early by anything loses no work: the run continues server-side and the same watch picks it up again.

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
| 6 | the wait ended early; the work continues server-side | run the resume command from the hint, which is the same `watch` again |
| 130 | interrupted by the user | the hint prints a resume and a cancel command; the run continues until one is chosen |

A `create` that already returned an instance id has started billing. On 6, 7, 130 or any later error, resume or inspect that instance; starting a second one is a new billed run and needs the user's explicit choice.

## `chat send` waits differently

`chat send` streams the agent's turn instead of polling: it prints text, a tool digest every 30 s and questions as they arrive, and gives up after two minutes of silence from the server, with no overall cap. A turn can take many minutes, so run the call in the background and read its output when it ends; `--tools` (every tool call with its arguments) stays off unless a turn needs diagnosing. Exit 6, or a call that ended before the footer, means the turn is still running; `chat get <chatId>` shows `processing` until it settles, then the transcript. Send the next message only after `processing` is false.
