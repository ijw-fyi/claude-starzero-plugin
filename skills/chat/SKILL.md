---
name: chat
description: 'Edits video and hands library-wide work to the StarZero agent: cuts, trims, reframing, captions, voiceover, music, graphics, generated clips, and analysis across a whole library. An edit of a video in a StarZero library happens here, not with local tools; a local recording joins a library through ingest-media first when the user wants it edited by the agent. Use when the user says "trim this to 60 seconds", "make it 9:16", "add captions", "add a lower-third", "edit this video", "make a highlight reel", "add a voiceover", "analyse the whole library" or "continue my chat".'
argument-hint: "[chat id or question]"
---

# Chat with the StarZero agent

Hands a task to the StarZero agent and relays the result. The agent is an agentic system with its own tools over the whole library: it searches and analyses the media, cuts and renders videos, generates video, graphics, voiceover, music, sound effects and images, and asks questions when it needs a decision. It does the fan-out over media itself, inside one chat. Argument: `$ARGUMENTS` is a chat id to continue or the task to hand over.

## What the agent can make

Brief it like a research analyst and an editor with a studio in one, and name what you want; it has more than cutting tools. Through the CLI, every tool runs without an in-app approval (the CLI opens chats with the gated tools pre-approved), so a brief that asks for generated footage or a library-wide scan gets it, billed as it goes.

- **Edits from library footage**: compilation and summary videos, highlight reels, cutdowns that keep the narrative, product comparisons, vertical and square versions for social media. Aspect ratios 21:9, 16:9, 4:3, 3:2, 2:1, 1:1, 4:5, 5:4, 3:4, 2:3, 9:16 and their inverses; reframing that follows the speaker or a named object; split-screen layouts; clip speed 0.25x to 12x; crossfades between clips; blur or a solid colour behind clips that leave part of the frame empty.
- **Graphics**: the designed ones (animated or static title cards, lower-thirds, badges, corner elements, background animations, intros and end cards) are made in this session, as SVG or MP4 files, and handed over for placement; `${CLAUDE_PLUGIN_ROOT}/reference/graphics.md` says how. The agent keeps captions and plain on-screen text, and generates a graphic itself only when the user asks for that.
- **Generated video**: short AI clips from a text prompt, from one or two images, or by restyling, editing or extending a library clip; intro cards, b-roll cutaways, logo end-cards, retro ads. Each clip is 3 to 10 seconds, extendable to 40; 16:9 or 9:16 only. Nineteen restyle looks, from anime and pixel art to art deco and cyberpunk, tuned for a person on camera.
- **Generated images**: thumbnails, posters, overlays, text and graphics composited onto a frame, up to 2K, from up to ten reference images or videos.
- **Audio**: voiceover or narration from a script, one voice per pass, chosen by gender, age, use (narration, social media, advertisement), accent and language, with delivery markers for emotion, tone, laughter and pauses; music from a prompt, 3 seconds to 5 minutes, instrumental unless lyrics are asked for; sound effects of half a second to 30 seconds, looping if wanted; floating audio tracks from the library or a URL; separating a clip's vocals from its background; volume keyframes.
- **Captions and text**: burned-in captions in one preset per video (Kamua, Word by Word, Word Highlight, Word Background Highlight, or plain on-screen text), per-word swaps and censoring, bleeped words, and transcript corrections (misheard words, name spellings, speaker names) that flow into the captions.
- **Deep analysis across a whole library**: it scans every item, however many, with a map-reduce pass over the library rather than one lookup at a time, and answers interpretive questions ("the funniest moments", "the first time they meet", "every claim about pricing across all interviews"), audits and compliance screening, cataloguing, themes, statistics, comparison tables across media, lists of people, products or claims, reports delivered as files, and web research after the library has been searched. A scan of a large library is one billed step inside the chat, not one chat per item.

A video with no library footage in it is possible: generated clips, graphics, voiceover and music combine on one timeline. The agent writes scripts from what is in the library, so a from-nothing piece needs the script, or the facts, in the brief.

What it cannot do: rotation, custom transitions, speed ramps, reverse playback, pitch shift or time stretch, noise reduction, EQ, colour grading, LUTs, stabilisation, face blurring, motion tracking or masks. It renders at source resolution, watermarked unless a clean render is asked for (billed). It edits one project at a time. Recordings the user wants analysed or cut go into the library first (`/starzero:ingest-media`); a link in the chat is stored as an asset at most, not analysed.

## Edit here, not locally

An edit of a video in a library is a chat task, whatever its size: a trim to a length, a 9:16 version, captions, a lower-third, a voiceover, a cutdown. The agent edits from the transcript's word timings, reframes by following the speaker, applies the caption presets, and checks the result before rendering. The same edit done with local tools on a downloaded file loses all of that: captions drift off the words, a fixed crop loses the speaker, and the result carries none of the checks. A local file the user is editing outside StarZero is not this skill's job. When the user wants for it what the agent does (captions on the words, a reframe that follows the speaker, graphics, voiceover), it goes through `/starzero:ingest-media` first, then the chat; otherwise, and whenever the user names a local tool, the edit is done locally, with one sentence on what the chat would have handled.

## One chat per task

- A chat is scoped to a library and sees all of it. "Scan the whole library", "find every mention of X across all interviews", "make a recap of everything from last week" is one chat with one message; the agent iterates over the media. Creating one chat per media item multiplies the billed turns, loses the cross-media view the agent has, and is the wrong shape for every task.
- Without `--content`, the chat covers the whole library: that is the default, and the right shape for anything library-wide. `--content <mediaId...>` is for a task about a handful of named items (one interview, these three clips), up to about ten. Past that, leave it out and put the selection in the brief instead ("only the interviews in /raw/q3", "everything from last week except the b-roll", "skip the files named draft"): the agent filters the library itself, and a list of hundreds of ids fills the chat's context with nothing the agent could not find on its own.
- Describe the task and the desired output in one message, the way you would brief a capable editor: the goal, the source material (library items, or none), constraints (length, format, aspect, tone, voice, music), and what to deliver. Name generated elements as such ("a 20-second animated title sequence with a voiceover reading this script, then the three best clips about X"). The agent breaks it into steps on its own; sending the steps one message at a time costs a turn each.
- Continue an existing chat for follow-ups on the same task ("shorter", "add the intro", "now do the same for the Q3 batch"); its context is already there. Start a new chat when the task is unrelated.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the plugin's StarZero connector offers the same API as tools and carries its own instructions; the commands in this skill apply where a shell exists.
- Exit 3 from any command means the login has expired (browser logins last 5 days), or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Scope the chat. `--library` is required and there is no default: run `starzero library list` and ask when more than one fits. Only when the user names a few specific items (up to about ten), take their media ids from `starzero media list --library <id> --status completed` (`--name <substring>` narrows it) for `--content`; a library-wide task, or a selection wider than that, takes no `--content` and names its filter in the brief (section above).
2. Find an existing chat when the user refers to one. `starzero chat list` lists chats newest first; `--query <text>` (3 or more characters) searches them semantically. A chat id the user pastes goes through `starzero chat get <chatId>` first; exit 4 is the only check a chat id gets.
3. Otherwise create one, a single chat for the whole task: `starzero chat create --library <id> [--content <mediaId...>] [--title <title>]`. Creating is free. Take the chat id and `appUrl` from `data`; pass the link through as printed. See `starzero chat create --help` for the rest.
4. Send the whole task in one message, with the billing in the Bash call's `description` (section below): `starzero chat send <chatId> --message "<text>"`. `--message-file <path>` (or `-` for stdin) carries a long message; `--file <path...>` uploads local files as artifacts of this chat and attaches them; `--artifact <type>/<id>` reattaches an artifact this chat already has. The CLI waits until the agent's turn ends, and a turn can take many minutes, so run the Bash call in the background and read the output when it ends. Leave `--tools` off as well: the 30 s digest is enough to follow a turn, and the per-call listing floods the context; turn it on only to diagnose a turn that went wrong. The reply streams as text (`Agent:` lines, a tool digest every 30 s, `?` question blocks) and ends with a `[done in m:ss · N tool calls · C credits · N tokens in context]` footer and the app link; the context figure is how full the chat is after the turn, mentioned only when the user asks. Read the exit code first.
5. When the summary carries `questions`, relay them to the user verbatim, wait for the answers, then send them as a new turn (asked about again, unless waived). Send the next message only after `chat get` shows `processing` false.
6. After exit 6, exit 8 or an interrupt: `starzero chat get <chatId> --json` and read `processing` (the one place JSON earns its tokens: a single boolean to poll). True means the agent is still working; run it again until false, then read the reply from the transcript with `starzero chat get <chatId> --last <n>` (or `--all`).
7. Collect what the chat produced. `starzero chat renders <chatId>` lists the videos; their render ids go to `/starzero:share-render` (`output url`, `output share`). `starzero artifact list --chat <chatId>` lists files (`--type` filters); `starzero artifact url <type>/<id>` prints a presigned URL to download with `curl -o <file> "<url>"`.
8. Deleting a chat or an artifact happens in the StarZero app; the CLI has no delete commands.

## Before each send

`chat send` bills one agent turn, and the cost is known only afterwards (the footer of the summary line shows it). Before every send, including one that answers the agent's questions or retries with `--artifact`:

1. Before the first send in a session, run `starzero credits` (free) for `creditsLeft`; a turn's own cost is known only afterwards, from the summary footer.
2. Ask once, in words, and wait for the answer: one question that carries the task, the billing and the balance ("Send the recap task to the StarZero agent; the turn is billed by what it does, 12,400 credits left. Go ahead?"). On the first send in a chat, add that the agent acts without further approval once the task is sent: it edits, renders, generates footage and audio, and scans the library on its own, each step billed. The user can waive this question for the session (`credits.md`, "Waiving the question"); the statement in step 1 still comes first, and the agent's own `questions` are always relayed. The Bash call's `description` repeats the billing line, for example `Send the recap task to the StarZero agent (billed turn; 12,400 credits left)`.
3. Run it once, after the yes. A send that timed out, was interrupted or lost its stream has started; `chat get` shows the result. A second send is a second bill and is asked about again.

## What to report

- The chat id and its app link, as the CLI printed them.
- The agent's reply text, and its questions verbatim when it asked any.
- The credits the turn used, from the summary footer.
- Render ids with their links from `/starzero:share-render`, and artifact keys with download URLs.
- Warnings from the `warnings` array, in the CLI's words.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 3 | login expired (5 days), or credential missing, invalid or lacking a scope | log in again (`auth.md`), then re-run |
| exit 8 on `chat send` | the agent is still busy with the previous turn | `chat get` until `processing` is false, then send once |
| exit 6 on `chat send`, or the call ended before the footer | the wait ended; the turn continues server-side | `chat get` until `processing` is false; send nothing meanwhile |
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
- `${CLAUDE_PLUGIN_ROOT}/reference/graphics.md`: read before making the first graphic for a video.
