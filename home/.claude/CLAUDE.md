## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background: skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, cut the preamble, and keep comments to the ones that earn their place.
- Bias toward prose unless we are actively implementing, debugging, reviewing, or prototyping code, or I explicitly ask for snippets. In brainstorming, design discussion, planning, tradeoff analysis, product thinking, and architecture conversations, do not pad the response with code examples.
- Scope is the request. A pre-existing bug, a perf concern, or behaviour the task never mentioned goes in the summary as a follow-up, unless the requested behaviour cannot work without it. Commit tests only where the task asks for them or the repo already keeps tests for that kind of change, sized like the neighbouring test files. Scratch checks stay scratch.

## Picking the right models for workflows and subagents

Reach for a subagent or a workflow when the work actually fans out (independent files, dimensions, or candidate approaches), when a result needs an independent adversarial check before it ships, or when the job is too big for one context to hold. A single-threaded task that fits in this context gets done inline; orchestration has real overhead and isn't the default. Once you are fanning out, pick the model per the table below.

Rankings are higher = better on each axis. Cost is what I actually pay through my subscriptions, not sticker price: my OpenAI limits are far more generous than my Claude ones, so the Codex models land cheaper than their Claude peers per unit of work. Intelligence is how hard a problem I can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model       | cost | intelligence | taste |
|-------------|------|--------------|-------|
| gpt-5.6-sol | 6    | 7            | 5     |
| sonnet-5    | 5    | 5            | 7     |
| gpt-6-astra | 4    | 8            | 8     |
| fable-5.1   | 2    | 9            | 9     |

How to apply:
- These are defaults, not limits; you have standing permission to override them. If a cheaper model's output misses the bar, redo the work with a stronger one without asking. Judge the output, not the price tag; escalating costs less than shipping something mediocre.
- Cost is only a tie-breaker. When the axes conflict on anything that ships, intelligence > taste > cost.
- Bulk / mechanical work (clear-spec implementation, data analysis, migrations): gpt-6-astra at `medium`. It outscores gpt-5.6-sol at medium by a wide margin while using fewer tokens. gpt-5.6-sol keeps only disposable volume (scratch scripts, data munging, one-off analysis); if it touches anything that ships, run it at `xhigh`, since its `medium` is the weakest useful configuration.
- Hard problems that need real intelligence but not Fable-class taste (gnarly debugging, algorithmic work, large refactors against a clear spec): gpt-6-astra at `high`, `xhigh` when it's gnarly. Never `max`: it buys under a point for 2.6x the tokens.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans or implementations: fable-5.1 at `high` is the primary reviewer, gpt-6-astra at `xhigh` the independent second opinion from a different lab. Use both when the change matters.
- Effort is the second lever after model. Fable 5.1 at `medium` roughly matches Fable 5, and at `low` it is often competitive with Opus and Sonnet on cost per task while scoring higher, so a `fable` agent at `effort: 'low'` or `'medium'` is a real option wherever you would otherwise run a smaller model harder. Keep `high` for reviews and anything intelligence-sensitive; `xhigh` and `max` are for measured gains only.
- Never use Haiku or Opus.
- Mechanics: Codex models (gpt-5.6-sol, gpt-6-astra) are only reachable through the Codex CLI. `~/.codex/config.toml` defaults to gpt-5.6-sol at medium reasoning, so pass `-m gpt-6-astra` (`-c model="gpt-6-astra"` for `codex review`) on every call unless Sol was chosen on purpose, and `-c model_reasoning_effort=<level>` whenever the level above isn't medium. For read-only investigation or data analysis, run `codex exec -s read-only` with a self-contained prompt. Claude models run via the Agent/Workflow `model` parameter: `'sonnet'` or `'fable'`.

Using Codex models inside workflows and subagents (the `model` parameter only accepts Claude models, so wrap it):
- Spawn a thin Claude wrapper agent, `model: 'sonnet', effort: 'low'`, whose only job is to write a self-contained Codex prompt, run it via Bash, and return the result. Put a `schema` on the wrapper to get structured output back.
- Write the prompt to a file and feed it to Codex over stdin (`codex exec -m gpt-6-astra < prompt.md`), not as an inline argument. Long inline prompts break on shell quoting and get truncated; a file is reliable and lets the prompt carry all the context Codex needs in one shot.
- Label these agents with the model slug as a prefix, e.g. `{label: 'gpt-6-astra:review-auth'}` or `{label: 'gpt-5.6-sol:migrate-schema'}`. The workflow UI only shows the wrapper's Claude model, so the label is the only signal of who did the work.
- Codex runs can blow past Bash's 10-minute timeout; for anything that might run long, launch through herdr (below) instead of background Bash so the run survives the wrapper.
- Parallel Codex implementation agents must use `isolation: 'worktree'` so their edits don't collide in the shared checkout.
- `codex exec` refuses to run outside a trusted directory (trust is per path in `~/.codex/config.toml`); from a fresh worktree or temp dir add `--skip-git-repo-check`.
- Workflow token budgets only count Claude tokens; Codex work is free and invisible to `budget.spent()`.

Running long Codex (or other CLI-agent) tasks under herdr:
- The herdr server owns the process, so runs survive wrapper/Bash death and output stays readable. CLI-launched work only: Agent/Workflow subagents are in-process API calls, and herdr can't manage those.
- If `herdr status server` says it's down, start `herdr server` as a background Bash task.
- The server is shared with other sessions: pick a short session tag, `herdr workspace create --label cc-<tag> --no-focus`, launch everything into that workspace, and never touch panes you didn't start.
- Launch: `herdr agent start cc-<tag>-<task> --workspace <ws_id> --cwd <dir> --no-focus -- bash -c 'codex exec < prompt.md > report.md; echo DONE_<tag>'`; note the `pane_id`.
- Block with `herdr wait output <pane_id> --match DONE_<tag> --timeout <ms>`; fleet = `herdr agent list` filtered on your `workspace_id`; tail via `herdr agent read`. Ignore `agent_status` for headless runs (TUI-only detection); the sentinel plus the report file is the truth.
- `herdr pane close` finished panes (leave failures open); `herdr workspace close <ws_id>` at session end.

## Sideshow Visuals

Use Sideshow by default for visual deliverables: UI mockups, HTML pages, dashboards, charts, diagrams, rendered explanations, presentations, and screenshots. Local Markdown, HTML, SVG, image files, code, or prose stand in only when I explicitly ask for them. If Sideshow is unavailable, say so and ask which fallback I want rather than writing a file.

Explicit requests to implement repository files are exempt; use Sideshow for visual review when relevant.
