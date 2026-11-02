---
name: starzero-skills
description: 'Manages the skills on a StarZero account, the instructions the StarZero agent loads in a chat and not Claude skills: lists and reads them, drafts a new one, pushes it after showing every file going up, pulls one to disk, marks one important. Use when the user says "save this as a StarZero skill", "show my StarZero skills", "push this skill to StarZero", "pull my cold-open skill" or "mark it important in StarZero".'
argument-hint: "[skill name, path, or what the new skill should do]"
---

# StarZero skills

Manages the skills stored on a StarZero account: instructions the StarZero agent loads in a chat. They are separate from Claude's own skills, although both are a SKILL.md with text files beside it. Argument: `$ARGUMENTS` is a skill name, a path, or what a new skill should do.

## Prerequisites

- This skill runs the `starzero` CLI in the shell. Every `starzero ...` below is run as `${CLAUDE_PLUGIN_ROOT}/scripts/starzero ...`: that launcher installs the pinned CLI on first use and hands over to it. Without a shell (claude.ai chat), the user manages skills in the StarZero app.
- Exit 3 from any command means the browser login was revoked or comes from a CLI before 0.16.0, or the credential is missing, invalid or lacks a scope. Log in again by the procedure in `${CLAUDE_PLUGIN_ROOT}/reference/auth.md` ("Logging in from a skill"), then re-run the command; when that fails, the user runs `/starzero:setup`.

## How the agent uses a skill

- A skill is a `name` (a slug), a `description`, a body, and optional text files beside it. It lives on the account, so every chat can use it.
- `/name` in a message loads it at once. The agent also searches the account's skills by itself, so a good description is what gets a skill used unasked.
- `important` puts the description in the agent's prompt in every chat, instead of leaving it to that search. It suits a skill that applies to most tasks.
- `skill list` shows the account's own skills, and the agent's built-in ones stay off that list. A skill with the same name as a built-in one takes its place on this account, so a new skill takes a specific name.

## Steps

1. To look: `starzero skill list` shows name, important flag, last update and description. `starzero skill get <name>` prints the SKILL.md and then its files by path and size; `--path <file>` prints one file.
2. To write a new skill, draft `<folder>/SKILL.md` in a new folder, a temporary one (`mktemp -d`) unless the user wants to keep it:

   ```markdown
   ---
   name: cold-open
   description: Opens a recap on its strongest claim. Use when a task asks for a cold open or a hook.
   ---

   Open on the strongest claim in the footage, under 8 seconds, with no title card.
   Cut straight to the first speaker afterwards.
   ```

   The body is written for the agent and states outcomes: what to make, in what order, how long, in what tone, and the user's house rules. Tool names, CLI commands and shell steps stay out, since the agent has its own tools and those change. The description says what the skill does and when it applies. `important: true` goes in the frontmatter when the user asks for it.
3. A Claude skill brought over is read first. One written around Claude's tools, shell commands or scripts gives the agent steps it cannot follow, so a copy is rewritten by step 2, its text files included, and the original stays as it is.
4. Before any push, show the user what goes up and wait for a yes: the SKILL.md for a new skill, and the file list from `find <folder> -type f` (or `unzip -l` for a `.skill` archive). Every text file in a folder is uploaded, `.env` and other hidden files included. When the folder holds a secret or anything that is not part of the skill, copy what belongs into a new folder and push that, leaving the original as it is. A stored skill is deleted only in the app, so this check comes before the send.
5. Push: `starzero skill push <path>`, where the path is a folder with SKILL.md at its root, one SKILL.md, or a `.skill` archive. The name comes from the frontmatter.
6. Exit 8 means the name is taken. Run `starzero skill get <name>`, tell the user what the stored skill holds, and ask before `starzero skill push <path> --replace`. A replace is whole: the stored files and the `important` flag become what is pushed, so a folder without `important: true` turns the flag off.
7. To edit a stored skill: `starzero skill pull <name> --out <dir>` writes `<dir>/<name>/SKILL.md` and its files, then step 4 and `--replace`. A pull overwrites that skill's files without asking and touches nothing else, so `<dir>` is a new folder unless the user is already working in one. The pulled SKILL.md keeps `important: true` when the flag is on. `--zip` writes `<dir>/<name>.skill` instead, the archive the StarZero app and Claude.ai import.
8. To change the flag: `starzero skill set <name> important on` (or `off`).
9. Deleting a skill happens in the StarZero app; the CLI has no delete command.

## Billing

Nothing in this skill spends credits. Using a skill is a normal `chat send`, billed as a turn by the chat skill.

## What to report

- The skill's name, whether it was created or replaced, its file count and its important flag.
- Every `warning:` line of a push, each naming a file that was left out.
- For a new skill: `/name` in a message loads it now, and the agent's prompt and search pick it up within 30 seconds.

## Failure modes

| Symptom | Meaning | What to do |
| --- | --- | --- |
| exit 2 on `push`, naming a field or file | it breaks a limit, or the path was not found | fix what the message names; the CLI holds the limits |
| exit 4 on `get`, `pull` or `set` | the name is not on the account; a built-in skill cannot be read here | take the name from `skill list`; for `--path`, the hint lists the skill's files |
| exit 8 on `push` | the name is taken | step 6 |
| exit 1 `FILE_ERROR` | the disk refused a read or write of the path it names | fix the path, or choose another `--out` |
| `warning:` "left out" on a push | a binary file, a symbolic link, or a file outside the skill's folder | copy a linked file in; a binary asset goes up with `starzero artifact upload` once the user agrees, since uploads cannot be deleted |

## Reference files

- `${CLAUDE_PLUGIN_ROOT}/reference/auth.md`: read on exit 3.
- `${CLAUDE_PLUGIN_ROOT}/reference/cli-conventions.md`: read when an exit code not covered above appears.
