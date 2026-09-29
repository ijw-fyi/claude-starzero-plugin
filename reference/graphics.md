# Graphics made here, placed by the StarZero agent

The designed graphics of a video (animated title cards, lower-thirds, badges, animated corner elements, background animations, intros and end cards) are made in this session and handed to the StarZero agent as files, which it places on the timeline. The agent keeps captions and plain on-screen text (a line of text with no design around it), unless the user asks otherwise; a lower-third is a designed graphic even though it carries text. This file is read before the first graphic is made.

The output aspect is the one the edit is being made in: the user's ask, or the chat's earlier turns (`chat get`). Ask when it is unknown; a graphic drawn for the wrong aspect is the usual reason one looks off.

## Two file forms

| Form | When | Rules |
| --- | --- | --- |
| SVG, static or animated | anything that sits over footage and needs transparency (lower-third, badge, corner element); full-frame pieces too | a `viewBox` on the root element; a full-frame piece is drawn at the output aspect (16:9, 9:16, 1:1...), an overlay element at its own natural proportions, and the brief says how large it sits in the frame; animation inside the file as SMIL or CSS `@keyframes` in a `<style>` block; every image inlined; fonts loaded by the file itself, with an `@import` of the Google Fonts stylesheet in the `<style>` block or a `@font-face` naming the font file's public https URL, or embedded base64, since a family named without its file renders in whatever the render host has |
| MP4 (H.264) | full-frame pieces with motion an SVG would struggle with; rendered with what the machine has (a headless browser plus ffmpeg, a rendering library) | the output's aspect and resolution, 25 or 30 frames per second, no transparency (an MP4 over footage covers it), checked with `ffprobe` when present: duration, resolution, codec |

When a browser tool is available in the session, open each SVG once to check it renders as intended; otherwise the agent's render is the check. Each file stays under 25 MiB (the server answers 413 above it). One element per file: a lower-third for each speaker is one file each, a title card is one file, so the agent can place, time and reuse them one by one. The uploaded key's type (`svg/...`, `video/...`) confirms the server read the file as a graphic; a `file/...` key means the extension or the bytes were off.

## The handoff, one turn

All files go on one `starzero chat send <chatId> --file <a.svg> <b.svg> <c.mp4> --message-file <brief>`. The brief is the placement list, in the timeline's own terms, and asks the agent to place the attached files as they are, since it has a graphics generator of its own and would otherwise make its version of a described lower-third:

```
Place the attached graphics as they are, without regenerating them:
- intro.mp4: full-frame clip at the start, 6 s, before the first interview clip.
- lower-third-ana.svg: overlay, over the first 5 s of each clip where Ana speaks, bottom-left, about a third of the frame wide, fade in and out 0.3 s.
- badge.svg: overlay, top-right corner, 12% of the frame wide, for the whole video.
```

Per element: which file, clip or overlay, start (a time, or a cue such as "when X first speaks") and duration, where in the frame (position and anchor), size relative to the frame, and any in or out motion not baked into the file. Captions stay on top of every graphic unless the user says otherwise, so a lower-third and the captions share the bottom of the frame without a layer note; a graphic meant to cover the captions says so. Motion inside the file (an SVG's own animation, the MP4's frames) needs no mention beyond its duration.

## After

The agent's render is the review point: watch the watermarked result (`chat renders`, then `/starzero:share-render`), and fix a graphic by editing its file and sending it again on the same chat, attached with `--file` (a new artifact) and a message that names what changed; `--artifact <type>/<id>` re-attaches an unchanged one.
