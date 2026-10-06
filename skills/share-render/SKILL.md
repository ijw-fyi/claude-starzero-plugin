---
name: share-render
description: 'Shares a StarZero workflow or podcast run as one public page, turns a render id into a public share page link to send or a signed private mp4 or thumbnail URL to download, and finds instance and render ids from a run or a chat. Use when the user says "share the run", "share the clips", "give me a link to the video", "download the output", "where are my rendered videos", "the share link expired", "stop sharing the run" or "thumbnail of that render".'
argument-hint: "[instance id or render id]"
---

# Share or download a render

Hands StarZero output over as a link. A workflow or podcast run is shared whole: one public page for every output of the run, with no expiry, until it is taken back. A single render goes out as a public share page for sending or a signed private URL for downloading, each with an expiry. When the user only has a run, a podcast run or a chat, it locates the ids first. Argument: `$ARGUMENTS` is an instance id or a render id the user already has.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the plugin's StarZero connector offers the same API as tools and carries its own instructions; the commands in this skill apply where a shell exists.
- Exit 3 from any command means the login has expired (browser logins last 5 days), or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## Steps

1. Take the instance id or render id from a view in this session; a typed or remembered id is the usual reason a link 404s. Find it in one of these:
   - A workflow run: `starzero workflow instance get <instanceId>`; the view shows `shared` and `sharePage` (the run's public page, null until shared), and each finished branch is one entry in `outputs[]` with its `renderId` and the chat link of the branch that made it. The instance id comes from `starzero workflow instance list` (`--status completed` narrows it).
   - A podcast run: `starzero podcast-clips list` prints instance ids, then the same `workflow instance get`.
   - A chat: `starzero chat renders <chatId>`; the chat id comes from `starzero chat list`.
   - A render id the user pastes: locate it in one of those views before signing it.
2. Every view with outputs sets `next.url` and `next.share` to the exact commands for the first render; run those verbatim, and substitute the render id for the other outputs. A finished run that is not shared also sets `next.shareRun` to its `workflow instance share` command.
3. Choose the command by purpose:
   - The run or its clips ("share the run", "share the clips", "send them the outputs"): `starzero workflow instance share <instanceId>` prints `page` (the run's public page, `https://share.starzero.ai/i/<instanceId>`), `shared` and `status`. The page shows every output of the run, has no expiry and stays public until `starzero workflow instance share <instanceId> --off`, after which it no longer shows the run. A run that is still going is shared at once, with a warning that the page fills in as outputs land; `next.shareRun` appears only on a finished run, so a user who wants a complete page is served by `instance watch` first, then `instance share`. Sharing a run that is already shared prints the same page again.
   - A link to one render to send to someone, or a link that expires: `starzero output share <renderId>` prints `page` (the public share page), `video` (the direct mp4) and `expiresAt`. Default and maximum expiry 7 days; `--expires <seconds>` shortens it. A chat's renders belong to no run, so this is their share route.
   - A download or a private link: `starzero output url <renderId>` prints `url` and `expiresInSeconds`. Default expiry 1 day, `--expires <seconds>` up to 7 days; `--thumbnail` returns the webp still instead of the mp4. Download with `curl -o <file> "<url>"`.
   - See `starzero output share --help` and `starzero output url --help` for the rest.
4. None of these links contains the API key; all are safe to paste. All three commands are free.
5. An expired link: run the same `output share` or `output url` command again; each run signs a fresh link. The run page does not expire: a run page that stopped showing the run was taken back with `--off`, and `instance get` shows `shared: false`.
6. A temporary render from `output render` has only the URL the command printed (valid about a day); it has no record, so `output url` and `output share` cannot serve it. Download it with `curl -o` while the URL is valid, or run the same `output render` command again for a fresh one (watermarked is free).
7. Files a chat used or produced are artifacts, not renders: `starzero artifact list --chat <chatId>` lists them and `starzero artifact url <type>/<id>` prints their presigned URL.

## Billing

`workflow instance share`, `output url` and `output share` spend nothing. The one billed path near this skill is a fresh `output render --no-watermark` (250 credits per rendered minute); before running it, state the exact command and the summed clip length, ask once in words ("Clean render of 42 s of clips, about 175 credits, 12,400 left. Go ahead?") and wait for the answer, unless the user waived the question for the session (`credits.md`, "Waiving the question"), then run it once, with the billing line repeated in the Bash call's `description` (for example `Clean render of 42 s of clips (billed; 12,400 credits left)`).

## What to report

- Which run or render each link belongs to: the run, the branch (with its chat link) or the chat, as the view printed them.
- The links exactly as the CLI printed them, with their expiry (`expiresAt` or `expiresInSeconds`) where they have one.
- For `workflow instance share`: that anyone with the page link sees every output of the run, with no expiry, and that `starzero workflow instance share <instanceId> --off` takes it back; for `output url`: that it is private and expires; for `output share`: that anyone with the page link can open it until `expiresAt`.
- For a downloaded file: the local path `curl -o` wrote.
- Warnings from the `warnings` array, in the CLI's words.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 3 | login expired (5 days), or credential missing, invalid or lacking a scope | log in again (`auth.md`), then re-run |
| exit 2, `--expires` rejected | the value is above 604800 seconds | lower it; 7 days is the maximum |
| exit 2, id of the wrong shape | the render id is not 24-hex | take it from `outputs[].renderId` or `chat renders` |
| the link 404s at the storage URL | no render exists under that id | locate the id in a view from this session and sign again |
| `outputs 0/n` on an instance view | the run is not finished or its branches failed | read `waiting.md`; `workflow instance watch <instanceId>` first, then `instance get` |
| warning `the run is still <status>` on `instance share` | the run is not finished; the page is public now and completes on its own as outputs land | relay it; `--off` takes the page back when the user wanted to wait for the complete run |
| exit 7 on `instance watch` | some branches failed | report which failed from the sessions table and their chat links before asking for links |
| UUID row in `chat renders` | a legacy video the CLI cannot serve; `output url` rejects it | the user opens it in the app |
| exit 4 on `instance get`, `instance share` or `chat renders` | the instance or chat id is mistyped | take the id from `instance list`, `podcast-clips list` or `chat list` |
| exit 6 on `output render` | the wait ended early and the render was cancelled | run the command again in the background; the prompt again when it carries `--no-watermark` |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/renders.md`: read before the first link; the run page, the URL, share and expiry rules.
- `${CLAUDE_PLUGIN_ROOT}/reference/ids-and-links.md`: read when the user pastes an id or asks where a link comes from.
- `${CLAUDE_PLUGIN_ROOT}/reference/waiting.md`: read when an instance view shows `outputs 0/n`.
- `${CLAUDE_PLUGIN_ROOT}/reference/credits.md`: read before any `output render --no-watermark`.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read on an exit code you have not seen.
