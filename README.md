# StarZero plugin for Claude Code

Upload media to StarZero, search transcripts and what is on screen, run workflow templates, cut
podcast clips, chat with the StarZero agent and share renders, from Claude Code, Cowork and
claude.ai chat. Where there is a shell, the plugin drives the
[`starzero` command-line tool](https://github.com/ijw-fyi/starzero-cli-releases) and installs it
for you; on claude.ai chat it offers the StarZero connector, a remote MCP server with the same
API as tools.

## Install

```sh
claude plugin marketplace add ijw-fyi/claude-starzero-plugin
claude plugin install starzero@starzero
```

Then, in a Claude Code session:

```
/starzero:setup
```

Setup downloads the CLI on first use, installs `ffprobe` next to it on Linux and Windows, then logs
you in: a browser tab opens on the StarZero login page, and the CLI stores the resulting token in
your OS credential store. Nothing is pasted into the chat. A browser login lasts 5 days; any skill
logs you in again when it has expired. On a machine without a browser, setup gives you a URL to
open on any device and asks for the address the login ends on. An API key from
https://app.starzero.ai/settings/api-keys works too (`starzero auth login --api-key`), for example
in a cloud session where `STARZERO_API_KEY` is set as an environment variable.

On macOS, install ffprobe with `brew install ffmpeg`; it is optional and only powers the credit
estimate before uploads.

## What you can ask for

| Skill | Ask for things like |
| --- | --- |
| `starzero:ingest-media` | "upload these recordings to my Interviews library and tell me when they are searchable" |
| `starzero:find-moments` | "find where they talk about pricing", "which clip shows the whiteboard", "compile those moments into one preview" |
| `starzero:run-workflow` | "run the highlights template on last week's uploads" |
| `starzero:podcast-clips` | "cut this episode into five vertical clips with captions" |
| `starzero:chat` | "ask the StarZero agent to make a two-minute recap of this library", "find every product mention across all interviews", "make an animated intro with a voiceover and music for this episode" (the agent works across the whole library in one chat, and generates video, graphics, voiceover, music and images) |
| `starzero:share-render` | "give me a link to the video", "download the output" |
| `starzero:setup` | install, log in, check scopes (you run this one yourself) |

Skills trigger on their own from what you say; `/starzero:<skill>` runs one directly.

## Credits and confirmation

Uploads, workflow runs, podcast clip runs, chat turns and clean (`--no-watermark`) renders spend
StarZero credits. Before each one, Claude states what the command bills and your balance (uploads
show the dry-run estimate, for example "about 48 credits, of 12,400 left") and asks whether to go
ahead. To skip the question, say so ("go ahead without asking") and it stays skipped for the rest
of the session; a line in your `CLAUDE.md` makes that permanent. Claude still tells you the cost
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
  only where the connector is used. Your credential is sent only to StarZero.
- Your credential lives in the OS credential store (Credential Manager, Keychain, Secret Service),
  or in `~/.starzero/credentials` (mode 0600) on a machine without one. `starzero auth logout`
  removes it and revokes a browser login token. The connector's sign-in token is separate and
  lives where your MCP client keeps such tokens: Claude Code's credential store, or claude.ai for
  chat; disconnecting the connector there ends it.
- The plugin has no hooks and no plugin options. It bundles one remote MCP server, the StarZero
  connector at `https://mcp.starzero.ai/mcp`, described below; no local MCP server.

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
  and is not needed.
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
test/launcher.sh               # downloads the pinned CLI into a temp HOME; keyring selection
scripts/check-versions.sh
```

Bumping the CLI: edit `reference/CLI_VERSION`, run `scripts/starzero --help` to review new
commands, update the skills and `reference/` docs that mention them, bump the plugin version in
both manifests, add a CHANGELOG entry, tag `vX.Y.Z`.

## License

MIT. The `starzero` CLI and ffprobe are downloaded at run time under their own licences.
