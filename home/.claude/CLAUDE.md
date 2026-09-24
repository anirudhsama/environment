## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background: skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, in plain literal phrasing with no mannered prose, and keep code comments to the ones that earn their place. A one-line note before you start and a short recap at the end are welcome; padding between them is not.
- Prose is the default in brainstorming, design discussion, planning, tradeoff analysis, product thinking, and architecture conversations. Code snippets belong in implementation, debugging, review, and prototyping, or when I ask for them.
- Scope is the request. A pre-existing bug, a perf concern, or behaviour the task never mentioned goes in the summary as a follow-up, unless the requested behaviour cannot work without it. Commit tests only where the task asks for them or the repo already keeps tests for that kind of change, sized like the neighbouring test files. Scratch checks stay scratch.
- Web search and URL fetches go through the Exa MCP. Anything newer than your training data gets searched, not recalled; a name you only half-recognize from a fast-moving area (AI models, developer tools) is a search too, with the name as I wrote it in at least one query. To scope results to specific sites or dates, use `web_search_advanced_exa` and its domain/date filters instead of typing `site:` into the query. `web_fetch_exa` takes a `urls` array, not `url`; raise `maxCharacters` when reading full docs pages.

## Picking the right models for workflows and subagents

Reach for a subagent or a workflow when the work actually fans out (independent files, dimensions, or candidate approaches), when a result needs an independent adversarial check before it ships, or when the job is too big for one context to hold. A single-threaded task that fits in this context gets done inline; orchestration has real overhead and isn't the default. Once you are fanning out, pick the model per the table below.

Rankings are higher = better on each axis. Cost is what I actually pay through my subscriptions, not sticker price: my OpenAI limits are far more generous than my Claude ones, so the Codex models land cheaper than their Claude peers per unit of work. Intelligence is how hard a problem I can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model       | cost | intelligence | taste |
|-------------|------|--------------|-------|
| gpt-5.6-sol | 6    | 7            | 5     |
| sonnet-5    | 5    | 5            | 5     |
| opus-5.5    | 5    | 8            | 8     |
| gpt-6-astra | 4    | 8            | 8     |
| fable-5.1   | 2    | 9            | 9     |

How to apply:
- These are defaults, not limits; you have standing permission to override them. If a cheaper model's output misses the bar, redo the work with a stronger one without asking. Judge the output, not the price tag; escalating costs less than shipping something mediocre.
- Cost is only a tie-breaker. When the axes conflict on anything that ships, intelligence > taste > cost.
- The workhorse is opus-5.5 at `medium`, its default: implementation, debugging, refactors, migrations, data analysis, and long unattended runs. gpt-5.6-sol at `medium` takes over when a fan-out is wide enough that my Claude limits become the constraint, or for bulk mechanical work where taste doesn't matter.
- fable-5.1 at `low` is often competitive with Opus and Sonnet on cost per task while scoring higher, so it is the other option for routine work. sonnet-5 is for thin wrappers and mechanical stages only.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7, which rules out Sol and Sonnet. Small UI work goes to opus-5.5; larger or intelligence-sensitive UI work to gpt-6-astra or fable-5.1. Opus falls back on stock frontend styles without direction, so name the specific patterns to avoid rather than asking for a non-generic look.
- Reviews of plans or implementations: fable-5.1 at `high`, with gpt-6-astra at `high` as the second opinion. Use both when the change matters. opus-5.5 at `medium` is the cheap first pass.
- Effort is the second lever after model. The Workflow `agent()` call takes `effort`; the Agent tool does not, and inherits the session's `high`. Keep `high` for reviews and anything intelligence-sensitive; `xhigh` and `max` only where the gain is measured.
- Defaults to know: an Agent or `agent()` call with no `model` inherits the session model (fable-5.1); the built-in Explore and Plan agents run opus-5.5. Set `model: 'opus'` explicitly for workhorse subagents.
- Opus 5.5 paces itself by elapsed time. For a team of Opus subagents, put a time budget in the prompt when you can estimate one; otherwise the line "Time matters here: do not spend time that can be avoided, and the earlier a correct result is obtained, the better."
- Never use Haiku.
- Claude models run via the Agent/Workflow `model` parameter: `'sonnet'`, `'opus'`, or `'fable'`. Codex models (gpt-5.6-sol, gpt-6-astra) run only through the Codex CLI; the exact flags, the wrapper-agent pattern for workflows, and herdr for long runs are in `~/.claude/codex.md`. Read it before any Codex call.

## Sideshow Visuals

Use Sideshow by default for visual deliverables: UI mockups, HTML pages, dashboards, charts, diagrams, rendered explanations, presentations, and screenshots. Local Markdown, HTML, SVG, image files, code, or prose stand in only when I explicitly ask for them. If Sideshow is unavailable, say so and ask which fallback I want rather than writing a file.

Explicit requests to implement repository files are exempt; use Sideshow for visual review when relevant.
