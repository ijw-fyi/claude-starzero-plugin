# Ids and links

## Ids: who hands them out, who takes them

| Id | Shape | Comes from | Goes to |
| --- | --- | --- | --- |
| library | 24-hex | `library list`, `library create` | `--library` on `folder`, `media`, `search`, `workflow instance create`, `podcast-clips create`, `chat create` |
| folder | a path such as `/raw/interviews`, not an id | `folder list`, `folder create` | `--folder`, `--to`, `--path` |
| media | 24-hex | `media list`, `media get`, `media upload` and `media import` rows, search hits (`mediaId`), `next.watch`, `workflow instance get --media` (`media[].id`) | `media get/move/url/download/thumbnail/watch`, `--media` on `search`, `workflow instance create`, `podcast-clips create`; `chat create --content` |
| template | 24-hex | `workflow template list`, `workflow template describe` | `workflow instance create --template`, `workflow instance list --template` |
| instance | 24-hex | `workflow instance create/list`, `podcast-clips create/list` (a podcast run is an instance) | `workflow instance get/watch/share/cancel` |
| session (a workflow branch) | chat-shaped string | instance views (`sessions`, `outputs[].sessionId`) | only the chat link the CLI prints; `chat send` to a branch session is not supported |
| chat | 1 to 64 URL-safe characters | `chat create`, `chat list` | `chat get/send/renders`, `artifact list --chat` |
| render | 24-hex | instance views (`outputs[].renderId`), `chat renders` | `output url`, `output share` |
| artifact | `<type>/<id>` | `artifact list`, `chat send` output lines | `artifact url`, `chat send --artifact` (same chat only) |

Rules:

- Take every id from a list or view in the same session; a typed or remembered id is the usual reason a link fails.
- A template id the user pastes goes through `workflow template describe` first: that validates it and adds it to `workflow template list` for next time (shared templates are not listed until then).
- `--media` accepts several ids; the CLI deduplicates them because fan-out templates bill per item.
- A UUID in `chat renders` is a legacy video id; `output url` rejects it, and the user opens it in the app.

## Links the CLI prints

Pass links through as printed; composing one by hand is unsupported.

| Link | Printed by | Purpose |
| --- | --- | --- |
| API keys page | `auth login --help`, hints | where the user mints a key |
| instance page (`link` / `appUrl`) | instance views | the run with its rendered videos |
| chat page (`appUrl`, `chatUrl`) | `chat create/get/send`, instance views per session and per output | the transcript; for a workflow run, the branch that produced an output, which is where a failed branch is diagnosed |
| run share page (`sharePage`, `page`) | instance views once shared, `workflow instance share` | public link to every output of a run, with no expiry, until `--off` |
| render share page (`page`) | `output share` | public link to a render, with an expiry |

## Folders

Folders are paths inside a library. `folder create --path /raw/interviews` before `media upload --folder /raw/interviews` or `media import --folder /raw/interviews`; both refuse a folder that does not exist.
