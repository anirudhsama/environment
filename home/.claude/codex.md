# Running Codex models (gpt-5.6-sol, gpt-6-astra)

Codex models are only reachable through the Codex CLI. Never rely on the defaults in `~/.codex/config.toml`; they drift (it has pointed at other models before). Pass the model and effort explicitly on every call: `codex exec -m gpt-5.6-sol -c model_reasoning_effort=medium` for bulk work, `-m gpt-6-astra -c model_reasoning_effort=high` for a review (`-c model="gpt-6-astra"` for `codex review`). For read-only investigation or data analysis, run `codex exec -s read-only` with a self-contained prompt.

## Inside workflows and subagents

The `model` parameter only accepts Claude models, so wrap it:
- Spawn a thin Claude wrapper agent, `model: 'sonnet', effort: 'low'`, whose only job is to write a self-contained Codex prompt, run it via Bash, and return the result. Put a `schema` on the wrapper to get structured output back.
- Write the prompt to a file and feed it to Codex over stdin (`codex exec -m gpt-5.6-sol -c model_reasoning_effort=medium < prompt.md`), not as an inline argument. Long inline prompts break on shell quoting and get truncated; a file is reliable and lets the prompt carry all the context Codex needs in one shot.
- Label these agents with the model slug as a prefix, e.g. `{label: 'gpt-6-astra:review-auth'}` or `{label: 'gpt-5.6-sol:migrate-schema'}`. The workflow UI only shows the wrapper's Claude model, so the label is the only signal of who did the work.
- Codex runs can blow past Bash's 10-minute timeout; for anything that might run long, launch through herdr (below) instead of background Bash so the run survives the wrapper.
- Parallel Codex implementation agents must use `isolation: 'worktree'` so their edits don't collide in the shared checkout.
- `codex exec` refuses to run outside a trusted directory (trust is per path in `~/.codex/config.toml`); from a fresh worktree or temp dir add `--skip-git-repo-check`.
- Workflow token budgets only count Claude tokens; Codex work is free and invisible to `budget.spent()`.

## Long runs under herdr

- The herdr server owns the process, so runs survive wrapper/Bash death and output stays readable. CLI-launched work only: Agent/Workflow subagents are in-process API calls, and herdr can't manage those.
- If `herdr status server` says it's down, start `herdr server` as a background Bash task.
- Headless runs use *pane* commands only. `herdr agent start` is for launching an interactive TUI agent into an existing shell pane (`--kind`, `--pane`); it cannot run an arbitrary command and rejects `--workspace`/`--cwd`. Don't reach for it, and don't run `herdr --skill` or `--help` to rediscover this.
- The server is shared with other sessions: pick a short session tag and create one workspace per session, one pane per task. Read IDs from the JSON, never guess them:
  `OUT=$(herdr workspace create --label cc-<tag> --cwd <dir> --no-focus)`; `WS=$(jq -r .result.workspace.workspace_id <<<"$OUT")`; `P=$(jq -r .result.root_pane.pane_id <<<"$OUT")`. Extra tasks: `herdr tab create --workspace $WS --cwd <dir> --no-focus` (same `.result.root_pane.pane_id` shape). Never touch panes you didn't create.
- Launch: `herdr pane run $P "bash -c 'codex exec -m <model> -c model_reasoning_effort=<level> ... < prompt.md > report.md 2> stderr.log; echo DONE_<tag>'"`. `pane run` types the command into the shell and presses Enter, so the pane must be at a shell prompt.
- Block with `herdr pane wait-output $P --regex '^DONE_<tag>$' --timeout <ms>`. Anchor the regex: the pane echoes the typed command line, so a bare `--match DONE_<tag>` fires immediately on the echo, before the job has run. Tail with `herdr pane read $P --source recent-unwrapped --lines <n>`; fleet with `herdr pane list --workspace $WS`. Ignore `agent_status` for headless runs (TUI-only detection); the sentinel plus the report file is the truth.
- `herdr pane close $P` finished panes (leave failures open). Closing the last pane removes the workspace; otherwise `herdr workspace close $WS` at session end.
