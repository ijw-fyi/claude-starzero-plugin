# StarZero plugin for Claude Code

Upload media to StarZero or import it from video URLs, search transcripts and what is on screen,
run workflow templates, cut podcast clips, chat with the StarZero agent, share renders and move
files to and from external storage such as Shade, from
Claude Code, Cowork and claude.ai chat. Where there is a shell, the plugin drives the
[`starzero` command-line tool](https://github.com/ijw-fyi/starzero-cli-releases) and installs it
for you; on claude.ai chat it offers the StarZero connector, a remote MCP server with the same
API as tools.

## Before you start

You need a StarZero account: sign up at https://app.starzero.ai. Everything that bills (uploads,
imports, workflow and podcast runs, chat turns, clean renders) draws on the credits of your plan,
so pick one in the app before the first of those; listing and inspecting what you already have
needs no credits. Claude Code is the surface this README describes; Cowork and claude.ai chat are
covered under "Other surfaces" below.

## Install

```sh
claude plugin marketplace add ijw-fyi/claude-starzero-plugin
claude plugin install starzero@starzero
```

Then, in a Claude Code session:

```
/starzero:setup
```

Until you are logged in, Claude is told at the start of each session to run setup first, so asking
for a StarZero job straight away works too.

Setup downloads the CLI on first use, installs `ffprobe` next to it on Linux and Windows, then logs
you in: a browser tab opens on the StarZero login page, and the CLI stores the resulting token in
`~/.starzero/credentials`, owner-only. Nothing is pasted into the chat. A browser login lasts 5 days; any skill
logs you in again when it has expired. On a machine without a browser, setup gives you a URL to
open on any device and asks for the address the login ends on. An API key from
https://app.starzero.ai/settings/api-keys works too (`starzero auth login --api-key`), for example
in a cloud session where `STARZERO_API_KEY` is set as an environment variable.

On macOS, install ffprobe with `brew install ffmpeg`; it is optional: it powers the credit
estimate before uploads and checks a graphic rendered as MP4 before it is handed over.

## What you can ask for

| Skill | Ask for things like |
| --- | --- |
| `starzero:ingest-media` | "upload these recordings to my Interviews library and tell me when they are searchable", "add this YouTube playlist to the library" |
| `starzero:find-moments` | "find where they talk about pricing", "which clip shows the whiteboard", "compile those moments into one preview" |
| `starzero:run-workflow` | "run the highlights template on last week's uploads" |
| `starzero:podcast-clips` | "cut this episode into five vertical clips with captions" |
| `starzero:chat` | "trim this interview to 60 seconds, 9:16, with captions", "add a lower-third with her name", "ask the StarZero agent to make a two-minute recap of this library", "find every product mention across all interviews", "make an animated intro with a voiceover and music for this episode" (an edit of library video goes through the agent, which works across the whole library in one chat and generates video, voiceover, music and images; Claude makes the designed graphics itself and hands them over for placement) |
| `starzero:share-render` | "give me a link to the video", "download the output" |
| `starzero:storage-providers` | "upload this render to our Shade drive", "list my Shade drives", "pull this clip from Shade into StarZero" (Shade is the first provider; you install rclone and jq, the plugin downloads nothing for it) |
| `starzero:setup` | install, log in, check scopes (you run this one yourself) |

Skills trigger on their own from what you say; `/starzero:<skill>` runs one directly.

## Credits and confirmation

Uploads, imports from video URLs, workflow runs, podcast clip runs, chat turns and clean
(`--no-watermark`) renders spend StarZero credits. Before each one, Claude states what the command
bills and your balance (uploads show the dry-run estimate, for example "about 48 credits, of
12,400 left"; imports have no estimate, and the server refuses a batch it cannot cover before
billing anything) and asks whether to go ahead. To skip the question, say so ("go ahead without
asking") and it stays skipped for the rest of the session; a line in your `CLAUDE.md` makes that
permanent. Claude still tells you the cost
before each billed command, and still asks about decisions that change what runs, such as
starting a second run while one is active.

## What the plugin downloads, runs and contacts

- The `starzero` CLI, about 40 MB, from
  [ijw-fyi/starzero-cli-releases](https://github.com/ijw-fyi/starzero-cli-releases) on GitHub, at
  the version pinned in `reference/CLI_VERSION`, verified against the release's `SHA256SUMS`
  before it runs. It is stored in `~/.starzero/bin/<version>/` (or
  `$STARZERO_CONFIG_DIR/bin/<version>/`). A plugin update may move the pin.
- `ffprobe` on Linux and Windows, 100 to 200 MB, an LGPL build from
  [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) verified against the publisher's
  checksums, stored next to the CLI.
- Hosts contacted: `github.com` and its release downloads for the two binaries; StarZero's own API
  (`api.starzero.ai`) and app (`app.starzero.ai`) for everything the skills do; `mcp.starzero.ai`
  only where the connector is used. Your StarZero credential is sent only to StarZero. When you use
  the storage-providers skill with Shade, `scripts/shade` contacts Shade's API (`api.shade.inc`)
  for listing, the key check and signed download URLs, and runs rclone against Shade's transfer
  API (`fs.shade.inc`) and the object-storage host that Shade's presigned upload and download URLs
  name; your Shade key goes only to Shade. Bringing a drive file into a StarZero library hands
  StarZero a signed download URL for that one file (valid one day), which its server fetches from
  Shade's storage; the fallback moves the file through your machine instead. rclone (1.73 or newer)
  and jq are tools you install yourself; the plugin downloads neither. When you hand the
  plugin a playlist, channel or folder URL and `yt-dlp` is installed on your machine, Claude runs
  it to list the video URLs, so that page is fetched from your machine; the videos themselves are
  fetched by StarZero's servers. The plugin installs nothing for this.
- On a crash of the CLI itself (an `INTERNAL` error, a bug), the CLI sends one report to StarZero's
  Sentry project (`ingest.us.sentry.io`): the error message, the command name, the CLI version,
  the platform and which kind of credential was in use; never your arguments, files, keys or
  tokens. It prints the report's event id. `DO_NOT_TRACK=1` or an empty `STARZERO_SENTRY_DSN=`
  in your environment turns it off.
- A Shade API key, if you store one, lives in `~/.starzero/shade-credentials` (or under
  `$STARZERO_CONFIG_DIR`), one line with mode 0600, written by `scripts/shade login --stdin` in
  your own terminal (Git Bash on Windows) and removed by `scripts/shade logout`; on macOS and
  Linux the script refuses the file when other users can read it. `SHADE_API_KEY` in the
  environment is read first. The script hands it to curl and rclone without putting it on a command line, and
  reads or writes no `rclone.conf`.
- Your StarZero credential lives in `~/.starzero/credentials` (or under `$STARZERO_CONFIG_DIR`), one line
  with mode 0600, on every platform; on macOS and Linux the CLI refuses the file when other users
  can read it. `starzero auth logout` removes it and revokes a browser login token. CLI versions
  before 0.8.0 used the OS keychain, and the CLI leaves that item alone: to remove it, delete the
  `starzero-cli` item in Keychain Access (macOS) or the generic credential whose name contains
  `starzero-cli` in Credential Manager (Windows). The connector's sign-in token is separate and
  lives where your MCP client keeps such tokens: Claude Code's credential store, or claude.ai for
  chat; disconnecting the connector there ends it.
- One hook, at session start: `scripts/session-start` puts the plugin's `scripts` folder on the
  PATH of the session's Bash commands, so a bare `starzero` resolves to the launcher (nothing is
  installed until the first command runs), and checks whether `~/.starzero/credentials` (or
  `$STARZERO_CONFIG_DIR/credentials`) exists or `STARZERO_API_KEY` is set; when neither is, it
  tells Claude to run `/starzero:setup` before the first StarZero request. It reads nothing else,
  contacts nothing, and prints nothing once you are logged in. No plugin options. It bundles
  one remote MCP server, the StarZero connector at `https://mcp.starzero.ai/mcp`, described below;
  no local MCP server.

## The StarZero connector

The plugin bundles StarZero's remote MCP server as a connector. It exposes the same API as tools
(libraries, media, search, workflows, podcast clips, renders, chats, artifacts), signs you in
through your browser when you connect it, and carries its own instructions for the model. It is
the route for claude.ai chat, where there is no shell.

One login per surface: with a shell, the skills use the CLI and its login, and the connector stays
disconnected. Claude Code lists it under `/mcp` as `plugin:starzero:starzero` with "needs
authentication"; that is expected, and connecting it there is harmless but gives you a second
login to the same account. On claude.ai chat, connect it from the plugin's Connectors tab.

The same server is also listed on its own in the claude.ai directory. When your account already
has that connector, Claude Code hides the plugin's copy rather than loading the same tools twice.
On claude.ai chat, if both appear, connect one; both carry the same tools.

## Other surfaces

- **Cowork**: the plugin installs and the skills work when the session runs on your computer;
  the browser login works the same way there. The connector shows on the plugin's Connectors tab
  and is optional, since the skills use the CLI.
- **Claude Code cloud sessions** (claude.ai/code): plugins are not loaded there. Install the CLI
  in the environment's setup script and set `STARZERO_API_KEY` as an environment variable or API
  credential; the CLI reads it first.
- **claude.ai chat**: no shell, so the skills' commands cannot run; the StarZero connector is
  the route, and the model follows the connector's instructions there.

## Development

```sh
claude --plugin-dir .          # load the working tree for one session
# Opening this repo in Claude Code also offers `.mcp.json` as a project MCP server; approve or skip it.
claude plugin validate . --strict
test/launcher.sh               # downloads the pinned CLI into a temp HOME and runs it
test/session-start.sh          # the SessionStart hook speaks only without a credential
test/shade.sh                  # scripts/shade against fake curl and rclone on PATH (needs jq)
scripts/check-versions.sh
```

Bumping the CLI: edit `reference/CLI_VERSION`, run `scripts/starzero --help` to review new
commands, update the skills and `reference/` docs that mention them, bump the plugin version in
both manifests, add a CHANGELOG entry, tag `vX.Y.Z`.

## License

MIT. The `starzero` CLI and ffprobe are downloaded at run time under their own licences.
