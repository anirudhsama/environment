# Running Codex models through the CLI

This is the route outside T3 Code. Inside T3 Code, use `delegate_task` as described in `CLAUDE.md`.

Never rely on the defaults in `~/.codex/config.toml`; they drift (it has pointed at other models before). Pass the model and effort explicitly on every call: `codex exec -m gpt-6-astra -c model_reasoning_effort=high` for a review (`-c model="gpt-6-astra"` for `codex review`; same shape for `gpt-6.1-sol`). For read-only investigation or data analysis, run `codex exec -s read-only` with a self-contained prompt.

## Inside workflows and subagents

The `model` parameter only accepts Claude models, so wrap it:
- Spawn a thin Claude wrapper agent, `model: 'opus', effort: 'low'`, whose only job is to write a self-contained Codex prompt, run it via Bash, and return the result. Put a `schema` on the wrapper to get structured output back.
- Write the prompt to a file and feed it to Codex over stdin (`codex exec -m gpt-6-astra -c model_reasoning_effort=high < prompt.md`), not as an inline argument. Long inline prompts break on shell quoting and get truncated; a file is reliable and lets the prompt carry all the context Codex needs in one shot.
- Label these agents with the model slug as a prefix, e.g. `{label: 'gpt-6-astra:review-auth'}` or `{label: 'gpt-6.1-sol:review-migration'}`. The workflow UI only shows the wrapper's Claude model, so the label is the only signal of who did the work.
- Codex runs can blow past Bash's 10-minute timeout; for anything that might run long, launch through Rex (below) instead of background Bash so the run survives the wrapper.
- Parallel Codex implementation agents must use `isolation: 'worktree'` so their edits don't collide in the shared checkout.
- `codex exec` refuses to run outside a trusted directory (trust is per path in `~/.codex/config.toml`); from a fresh worktree or temp dir add `--skip-git-repo-check`.
- Workflow token budgets only count Claude tokens; Codex work is free and invisible to `budget.spent()`.

## Long runs under Rex

- The Rex server owns the process, so runs survive wrapper/Bash death and the user can watch them in the Rex app. CLI-launched work only: Agent/Workflow subagents are in-process API calls that Rex can't hold. The `rex` skill covers the CLI; this is the Codex recipe on top of it.
- One session per Claude session, one tab per task. Read IDs from the JSON, never guess them, and touch only what you created:
  `S=$(rex new cc-<tag> -c <dir> --json | jq -r .session_id)`
  `B=$(rex run -s $S -c <dir> --label <task> --keep-open --focus=false --json -- sh -c 'codex exec -m <model> -c model_reasoning_effort=<level> ... < prompt.md > report.md 2> stderr.log; echo $? > exit.code' | jq -r '.block_ids[0]')`
- Block with `rex wait -s $S $B --for 9m`, repeated until `exit.code` exists; this keeps each call under Bash's 10-minute limit. Exit 1 means a timeout or a Codex failure alike, so `exit.code` and `report.md` are the truth. `rex capture -s $S -b $B --trim | tail -n <n>` reads the screen mid-run.
- `rex block close -s $S $B` finished tabs and leave failures open. At session end, `rex kill $S` once no failure is left open for the user.
