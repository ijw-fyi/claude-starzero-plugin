---
name: chat
description: 'Hands a task to the StarZero agent, an agentic system over a whole library: library-wide analysis, cross-media comparison, video editing and creation. One chat carries one task, however many media it touches. Creates or continues the chat, relays its questions, collects what it produced. Use when the user says "ask StarZero to", "analyse the whole library", "make a highlight reel" or "continue my chat".'
argument-hint: "[chat id or question]"
---

# Chat with the StarZero agent

Hands a task to the StarZero agent and relays the result. The agent is an agentic system with its own tools over the whole library: it reads every transcript, searches, compares media, cuts and renders videos, and asks questions when it needs a decision. It does the fan-out over media itself, inside one chat. Argument: `$ARGUMENTS` is a chat id to continue or the task to hand over.

## One chat per task

- A chat is scoped to a library and sees all of it. "Scan the whole library", "find every mention of X across all interviews", "make a recap of everything from last week" is one chat with one message; the agent iterates over the media. Creating one chat per media item multiplies the billed turns, loses the cross-media view the agent has, and is the wrong shape for every task.
- `--content <mediaId...>` narrows the agent's attention to named items when the user asks for a task about those specific items. Leave it out for anything library-wide.
- Describe the task and the desired output in one message, the way you would brief a capable editor: the goal, constraints (length, format, aspect, tone), and what to deliver. The agent breaks it into steps on its own; sending the steps one message at a time costs a turn each.
- Continue an existing chat for follow-ups on the same task ("shorter", "add the intro", "now do the same for the Q3 batch"); its context is already there. Start a new chat when the task is unrelated.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. The plugin puts it on PATH; when the bare name is not found, call the launcher by path, `${CLAUDE_PLUGIN_ROOT}/scripts/starzero`, which installs the CLI on first use. On claude.ai chat there is no shell, so this skill cannot run there.
- Exit 3 from any command means the key is missing, invalid or lacks a scope: stop and ask the user to run `/starzero:setup`.

## Steps

1. Scope the chat. `--library` is required and there is no default: run `starzero library list` and ask when more than one fits. Only when the user names specific items, take their media ids from `starzero media list --library <id> --status completed` (`--name <substring>` narrows it) for `--content`; a library-wide task takes no `--content`.
2. Find an existing chat when the user refers to one. `starzero chat list` lists chats newest first; `--query <text>` (3 or more characters) searches them semantically. A chat id the user pastes goes through `starzero chat get <chatId>` first; exit 4 is the only check a chat id gets.
3. Otherwise create one, a single chat for the whole task: `starzero chat create --library <id> [--content <mediaId...>] [--title <title>]`. Creating is free. Take the chat id and `appUrl` from `data`; pass the link through as printed. See `starzero chat create --help` for the rest.
4. Send the whole task in one message, with the billing in the Bash call's `description` (section below): `starzero chat send <chatId> --message "<text>"`. `--message-file <path>` (or `-` for stdin) carries a long message; `--file <path...>` uploads local files as artifacts of this chat and attaches them; `--artifact <type>/<id>` reattaches an artifact this chat already has. Leave `--timeout` off: the CLI waits until the agent's turn ends, and a turn can take many minutes, so give the Bash call itself the longest timeout the tool allows (600000 ms) rather than capping the wait. Leave `--tools` off as well: the 30 s digest is enough to follow a turn, and the per-call listing floods the context; turn it on only to diagnose a turn that went wrong. The reply streams as text (`Agent:` lines, a tool digest every 30 s, `?` question blocks) and ends with a `[done in m:ss · N tool calls · C credits]` footer and the app link. Read the exit code first.
5. When the summary carries `questions`, relay them to the user verbatim, wait for the answers, then send them as a new turn (through the prompt again). Send the next message only after `chat get` shows `processing` false.
6. After exit 6, exit 8 or an interrupt: `starzero chat get <chatId> --json` and read `processing` (the one place JSON earns its tokens: a single boolean to poll). True means the agent is still working; run it again until false, then read the reply from the transcript with `starzero chat get <chatId> --last <n>` (or `--all`).
7. Collect what the chat produced. `starzero chat renders <chatId>` lists the videos; their render ids go to `/starzero:share-render` (`output url`, `output share`). `starzero artifact list --chat <chatId>` lists files (`--type` filters); `starzero artifact url <type>/<id>` prints a presigned URL to download with `curl -o <file> "<url>"`.
8. Deleting a chat or an artifact happens in the StarZero app; the CLI has no delete commands.

## Before each send

`chat send` bills one agent turn, and the cost is known only afterwards (the footer of the summary line shows it). Before every send, including one that answers the agent's questions or retries with `--artifact`:

1. Before the first send in a session, run `starzero credits` (free) for `creditsLeft`; a turn's own cost is known only afterwards, from the summary footer.
2. Run it, with the billing in the Bash call's `description`, for example `Send the recap task to the StarZero agent (billed turn; 12,400 credits left)`. On the first send in a chat, add that the agent acts on the library without further approval: `Send the recap task to the StarZero agent (billed turn; renders and edits without asking; 12,400 credits left)`. The plugin's permission prompt shows that description, so it is the confirmation; nothing is asked in words, before or after. Ask a question only when there is a decision to make: the prompt is off (the user chose that), or the agent's own `questions` need the user's answer.
3. Run it once. A send that timed out, was interrupted or lost its stream has started; `chat get` shows the result. A second send is a second bill and goes through the prompt again.

## What to report

- The chat id and its app link, as the CLI printed them.
- The agent's reply text, and its questions verbatim when it asked any.
- The credits the turn used, from the summary footer.
- Render ids with their links from `/starzero:share-render`, and artifact keys with download URLs.
- Warnings from the `warnings` array, in the CLI's words.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 3 | key missing, invalid or lacking a scope | stop; ask the user to run `/starzero:setup` |
| exit 8 on `chat send` | the agent is still busy with the previous turn | `chat get` until `processing` is false, then send once |
| exit 6 on `chat send`, or the Bash call is cut off | the wait ended; the turn continues server-side | `chat get` until `processing` is false; send nothing meanwhile |
| exit 1 `CHAT_TURN_FAILED` | the turn failed, including insufficient credits | relay the message and `hint`; stop |
| `CHAT_STREAM_CLOSED` | the stream ended before the summary | `chat get` for the reply; send nothing |
| `uploaded` event, then the send failed | the file is an artifact of the chat already | resend with `--artifact <type>/<id>` from that event; the prompt covers the resend |
| exit 4 on `--artifact` | the key belongs to another chat or is mistyped | `artifact list --chat <chatId>` and take the key from there |
| server rejects a `--file` (413) | the file is over 25 MiB | attach a smaller file |
| exit 4 on `chat get` | the chat id is mistyped | take the id from `chat list` |
| exit 2 on `chat list --query` | the query is under 3 characters | lengthen the query or list without it |
| UUID row in `chat renders` | a legacy video the CLI cannot serve | the user opens it in the app |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before the first send; the rule for billed commands.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read the `chat send` section before the first send and on exit 6.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when parsing the NDJSON stream or an exit code you have not seen.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read when the user pastes a chat, media or artifact id.
- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before handing over a render from `chat renders`.
