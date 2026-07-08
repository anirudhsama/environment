## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background — skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, cut the preamble, and keep comments to the ones that earn their place.

## Picking the right models for workflows and subagents

Rankings below are higher = better on each axis. Cost is what I actually pay — gpt-5.5 runs on a priority Codex tier that's effectively free for me — not sticker price. Intelligence is how hard a problem I can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model    | cost | intelligence | taste |
|----------|------|--------------|-------|
| gpt-5.5  | 9    | 8            | 5     |
| sonnet-5 | 5    | 5            | 7     |
| opus-4.8 | 4    | 7            | 8     |
| fable-5  | 2    | 9            | 9     |

How to apply:
- These are defaults, not limits — you have standing permission to override them. If a cheaper model's output misses the bar, redo the work with a stronger one without asking. Judge the output, not the price tag; escalating costs less than shipping something mediocre.
- Cost is only a tie-breaker. When the axes conflict on anything that ships, intelligence > taste > cost.
- Bulk / mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.5 — it's effectively free.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans or implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- Never use Haiku.
- Mechanics: gpt-5.5 is only reachable through the Codex CLI — `codex exec` / `codex review` (my `~/.codex/config.toml` already defaults to gpt-5.5). For read-only investigation or data analysis, run `codex exec -s read-only` with a self-contained prompt. Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent/Workflow `model` parameter.

Using gpt-5.5 inside workflows and subagents (the `model` parameter only accepts Claude models, so wrap it):
- Spawn a thin Claude wrapper agent — `model: 'sonnet', effort: 'low'` — whose only job is to write a self-contained Codex prompt, run it via Bash, and return the result. Put a `schema` on the wrapper to get structured output back.
- Write the prompt to a file and feed it to Codex over stdin (`codex exec < prompt.md`), not as an inline argument. Long inline prompts break on shell quoting and get truncated; a file is reliable and lets the prompt carry all the context Codex needs in one shot.
- Label these agents with a `gpt-5.5:` prefix, e.g. `{label: 'gpt-5.5:review-auth'}`. The workflow UI only shows the wrapper's Claude model, so the label is the only signal that the real worker is gpt-5.5.
- Codex runs can blow past Bash's 10-minute timeout — pass an explicit longer timeout, or run in the background and poll for the report file.
- Parallel gpt-5.5 implementation agents must use `isolation: 'worktree'` so Codex's edits don't collide in the shared checkout.
- Workflow token budgets only count Claude tokens; Codex work is free and invisible to `budget.spent()`.

## Sideshow Visuals

Sideshow MCP is configured for visual work. When asked for UI mockups, HTML pages, data visualizations, diagrams, rendered explanations, screenshots, or similar visual artifacts, consider using Sideshow so the result can be reviewed visually instead of only described in text.
