# Credits

StarZero bills in credits. These commands spend them:

| Command | What is billed | Estimate available |
| --- | --- | --- |
| `media upload` | processing of the new media | yes: `media upload --dry-run` (needs ffprobe and `billing:read`) |
| `workflow instance create` | the whole run, per fan-out item | no |
| `podcast-clips create` | the whole run | no |
| `chat send` | the agent turn | no; the footer shows what it cost afterwards |
| `output render --no-watermark` | a clean temporary render, per rendered minute | the summed clip length (`durationSeconds`) is the driver; the watermarked default is free |

Billing starts at the request. `workflow instance cancel` stops a run and refunds nothing. Everything else (`list`, `get`, `describe`, `watch`, `search`, `url`, `share`, `download`, `thumbnail`) is free.

## Before spending

Before any of the billed commands:

1. Run `starzero credits` and say what will run, as the exact command, what it bills, and the balance it draws on (`creditsLeft`, plus the soonest note expiry when one is close): the estimate from `--dry-run` for uploads, "one run of template X on N media items" for workflows, "one clip run" for podcasts, "one agent turn" for chats, "a clean render of N seconds" for `--no-watermark`.
2. Confirm once, through the prompt. Put the billing in the Bash call's `description` (`Upload 3 files to Interviews (bills ~48 credits, 12,400 left)`, `Start workflow X on 5 media (billed run; 12,400 credits left)`): the plugin's permission prompt ("Ask before spending credits") shows that description, so the user sees the cost and the balance in the box and confirms there. A yes in words on top of it is one too many. Questions in words are for decisions: the prompt is off (the user chose that in `/config`), a run is already active, validation was skipped, or a flag such as `--force` or `--skip-credit-check` is being considered.
3. Run it once. A create that errored after returning an id, timed out, or was interrupted has started; `waiting.md` covers resuming it. A second create is a second bill and goes through the prompt again.

## One run at a time

Workflow runs and podcast-clip runs draw on the same balance as they go. Two runs in flight can both run out and fail where one alone would have finished, and cancelling refunds nothing. Before `workflow instance create` or `podcast-clips create`, check `starzero workflow instance list --status queued` and `--status pending`; when a run is active, watch it to completion (or let the user cancel it) before starting the next. A multi-media job is one instance with several `--media`, not several instances. A parallel start is the user's explicit decision, asked in words.

## Seeing the numbers

- `starzero credits` is free and shows the account as a short table: the credits left, the plan and its term end ("free" without a subscription), and the credit notes still holding credits, soonest expiry first. `--json` gives the same as `{ "creditsLeft", "plan", "notes" }`. It needs `billing:read`.
- `media upload --dry-run` prints the estimate next to the balance (`~N credits (M left)`) and refuses with exit 5 when the estimate exceeds the balance or the storage limit. `--skip-credit-check` bypasses that refusal; offer it only when the user asks to proceed anyway. Any exit 5 for lack of credits points at `starzero credits`.
- Spend shows up as `creditsUsed` on instance views, per session in the sessions table, and in the `chat send` footer.
- Workflow and podcast runs take a while (minutes to tens of minutes) and can use a large share of a balance. When `creditsLeft` is under 100,000 before a `workflow instance create` or `podcast-clips create`, put a warning in the permission box title ("balance is low for a workflow run: 42,000 credits left") so the user decides with that in view.

## Warnings that still bill

`workflow instance create` proceeds when `workflow template describe` fails on an older template and reports `variables were not validated` in `warnings`. The run started. When `describe` failed before the create, say validation was skipped and ask whether to go ahead.
