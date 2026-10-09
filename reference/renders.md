# Renders and outputs

A render is a video StarZero produced. Kept renders come from workflow runs, podcast-clip runs (which are workflow runs) and chats. Temporary renders come from `output render`, which cuts moments into one video on demand. A kept render's id is a 24-hex id that appears in:

- `workflow instance get <id>` and `workflow instance watch <id>`: `outputs[].renderId`, one per finished branch, each with the chat link of the branch that made it;
- `chat renders <chatId>`: the videos a chat rendered.

Every view with outputs sets `next.url` and `next.share` to the exact commands for the first render; a finished run that is not shared also sets `next.shareRun` to its `workflow instance share` command. Every instance view carries `shared` and `sharePage` (the run's public page, null until shared). `workflow instance get <id> --library --media` adds `library` (`{ id, name, ... }`, or null when it no longer exists) and `media` (the selected media that still exist, in selection order, each with `name`, `status`, `duration` and `origin`; empty for a whole-library run) next to the unchanged `libraryId` and `mediaIds`; a missing input is named in `warnings`. One assets call for the library and one per media, so ask for them when the question is what the run worked on.

## Three ways to hand output over

| Command | Gives | Default expiry | Max | Use when |
| --- | --- | --- | --- | --- |
| `workflow instance share <instanceId>` | one public page for every output of the run, `https://share.starzero.ai/i/<instanceId>`; `--off` takes it back | none | none | the user wants to share a run or its clips |
| `output url <renderId>` | a signed private URL to the mp4 (`--thumbnail` for the still) | 1 day | 7 days | the user wants to download it, or you pipe it to `curl -o` |
| `output share <renderId>` | a public share page plus a direct mp4 link, both with an expiry | 7 days | 7 days | the user wants a link to send to someone |

JSON shapes: `instance share` returns `{ "instanceId", "shared", "page", "status", "isDone" }` (`page` is null after `--off`); `url` returns `{ "renderId", "file", "url", "expiresInSeconds" }`; `share` returns `{ "renderId", "page", "video", "expiresAt" }`. `--expires` takes seconds, up to 604800; a larger value is a usage error.

The run page is the route for "share the run" and "share the clips": a podcast run is an instance, so it is shared the same way. Sharing a run that is still going warns that the page fills in as outputs land; sharing a shared run changes nothing and prints the same page. A chat's renders belong to no run, so `output share` is their share route. All three commands are free.

None of these links contains the API key, so all are safe to paste.

## Temporary renders from moments

`starzero output render --library <id> --clip <mediaId>:<start>-<end> [--clip ...]` cuts the given moments, in order, into one video and prints a signed URL. The ranges are the ones `search transcript` and `search visual` print (seconds, decimals allowed), so this is how the user looks at what a search found, or downloads it.

- Watermarked by default, and free. `--no-watermark` gives a clean render, bills credits (per rendered minute); it counts as a billed command under `credits.md`.
- `--height` (default 1080) and `--aspect` (`9:16`, `2:3`, `4:5`, `1:1`, `5:4`, `16:9`; default keeps the source ratio) size the output.
- The command blocks until the render is done, with no limit of its own. A short compilation takes seconds; a long one runs in the background as `waiting.md` describes. Exit 6 means the wait ended early and the render was cancelled.
- The URL is the whole result: a temporary render has no record, so `output url` and `output share` cannot serve it, and there are no `next` hints. The URL is valid for about a day and the file for longer; download it with `curl -o` while it is. JSON: `{ "renderId", "width", "height", "durationSeconds", "url", "urlExpiresInSeconds" }`.

## Rules

- Render ids come from a view in this session. An id from memory or from the user's typing is the usual reason a link fails with a 404.
- `outputs 0/n` on an instance view means the run is not finished or its branches failed; go back to `waiting.md` before asking for links.
- A UUID row in `chat renders` is a legacy video the CLI cannot serve; the user opens that one in the app.
- Artifacts are not renders. `artifact url <type>/<id>` gives a presigned URL for a file a chat used or produced: an uploaded image or document, and the generated pieces (`gen-video`, `gen-image`, `gen-tts`, `gen-music`, `gen-sfx`, `svg`); a render is the compiled output. Use `chat renders` for the videos and `artifact list --chat <id>` for everything else.
