---
name: cli
description: 'Where the starzero CLI is and how it is run: the CLI is not on PATH, it lives under ~/.starzero/bin/ and this skill installs it when it is missing. Use for any StarZero or starzero request that no other starzero skill covers, and before any bare `starzero` command, such as "which starzero version is installed", "list my libraries", "show my chats", "what can starzero do", or a starzero command the user names.'
---

# The starzero CLI

The plugin reaches StarZero through the `starzero` CLI. This skill says where it is; the other starzero skills carry the procedures for their jobs, and a request one of them covers (uploading, finding moments, a chat with the agent, a workflow run, clips, sharing a render, account skills, setup) goes to that skill.

## Where it is

- Every `starzero ...` command is run as `$HOME/.starzero/bin/0.18.0/starzero ...` (`starzero.exe` on Windows; `$STARZERO_CONFIG_DIR` replaces `$HOME/.starzero` when it is set). Nothing puts it on PATH, so a bare `starzero` fails, and a `starzero` found elsewhere on the machine is another install, not the plugin's.
- When that file is missing, install it with the commands in `${CLAUDE_PLUGIN_ROOT}/reference/install.md`: the release asset for this machine from GitHub, checked against the release's `SHA256SUMS`, unpacked into the version folder. The plugin itself holds no program.
- A command meant for the user's own terminal carries that absolute path.
- `starzero --help` lists the command groups; `starzero <group> --help` lists each group's commands. `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md` explains exit codes and output shapes: exit codes decide, stdout informs.

## Login

- Exit 3 from any command means the browser login was revoked or comes from a CLI before 0.16.0, or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.
- The plugin's StarZero MCP connector is a separate, optional route with its own sign-in, for claude.ai chat where there is no shell. It being unauthenticated says nothing about the CLI: the CLI and the skills work without it.

## Billing

Some commands spend credits. Read `${CLAUDE_PLUGIN_ROOT}/reference/credits.md` before the first command that bills, and ask the question it describes.
