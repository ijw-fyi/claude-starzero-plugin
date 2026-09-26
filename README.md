# StarZero plugin for Claude Code

Upload media to StarZero, search transcripts and what is on screen, run workflow templates, cut
podcast clips, chat with the StarZero agent and share renders, from Claude Code and Cowork. The
plugin drives the [`starzero` command-line tool](https://github.com/ijw-fyi/starzero-cli-releases)
and installs it for you.

## Install

```sh
claude plugin marketplace add ijw-fyi/claude-starzero-plugin
claude plugin install starzero@starzero
```

Claude Code asks for your StarZero API key during install. Create one at
https://app.starzero.ai/settings/api-keys with the scopes `profile:read`, `billing:read`,
`library:read`, `library:search`, `rendering:read` and `rendering:write`. The key is stored by
Claude Code outside your settings file and handed to the CLI; it appears in no transcript.

Then, in a Claude Code session:

```
/starzero:setup
```

Setup downloads the CLI on first use (a ~40 MB verified download from GitHub releases), installs
`ffprobe` next to it on Linux and Windows (about 100 to 200 MB, an LGPL build from
[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)), checks your key and lists the scopes
it carries. On macOS, install ffprobe with `brew install ffmpeg`; it is optional and only powers the
credit estimate before uploads.

## What you can ask for

| Skill | Ask for things like |
| --- | --- |
| `starzero:ingest-media` | "upload these recordings to my Interviews library and tell me when they are searchable" |
| `starzero:find-moments` | "find where they talk about pricing", "which clip shows the whiteboard", "compile those moments into one preview" |
| `starzero:run-workflow` | "run the highlights template on last week's uploads" |
| `starzero:podcast-clips` | "cut this episode into five vertical clips with captions" |
| `starzero:chat` | "ask the StarZero agent to make a two-minute recap of this library", "find every product mention across all interviews" (the agent works across the whole library in one chat) |
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
Please keep the plugin's hooks enabled: `disableAllHooks` also removes the hook that puts the CLI
on PATH.

## Where things live

- CLI and ffprobe: `~/.starzero/bin/<version>/` (or `$STARZERO_CONFIG_DIR/bin/<version>/`).
- API key: written by the plugin to `~/.starzero/credentials` (mode 0600) from the option you set
  at install. Clear the option in `/config` to manage the key yourself with `starzero auth login`.
- The pinned CLI version is in `reference/CLI_VERSION`; a plugin update may move it.

## Other surfaces

- **Cowork**: the plugin installs and the skills work when the session runs on your computer.
  Cowork does not ask for plugin options, so `/starzero:setup` asks you to paste the key in the
  chat and stores it in your OS credential store. The conversation keeps a copy; revoke the key
  from the API keys page if that ever concerns you. Setting `STARZERO_API_KEY` in your environment
  works too.
- **Claude Code cloud sessions** (claude.ai/code): plugins are not loaded there. Install the CLI
  in the environment's setup script and set `STARZERO_API_KEY` as an environment variable or API
  credential; the CLI reads it first.
- **claude.ai chat**: the plugin installs but has no shell to run the CLI, so the skills cannot
  act there.

## Development

```sh
claude --plugin-dir .          # load the working tree for one session
claude plugin validate . --strict
test/hooks.sh                  # session-start hook, no network
test/launcher.sh               # downloads the pinned CLI into a temp HOME
scripts/check-versions.sh
```

Bumping the CLI: edit `reference/CLI_VERSION`, run `scripts/starzero --help` to review new
commands, update the skills and `reference/` docs that mention them, bump the plugin version in
both manifests, add a CHANGELOG entry, tag `vX.Y.Z`.

## License

MIT. The `starzero` CLI and ffprobe are downloaded at run time under their own licences.
