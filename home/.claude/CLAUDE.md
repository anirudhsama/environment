## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background: skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, in plain literal phrasing with no mannered prose, and keep code comments to the ones that earn their place. A one-line note before you start and a short recap at the end are welcome; padding between them is not.
- Prose is the default in brainstorming, design discussion, planning, tradeoff analysis, product thinking, and architecture conversations. Code snippets belong in implementation, debugging, review, and prototyping, or when I ask for them.
- Scope is the request. A pre-existing bug, a perf concern, or behaviour the task never mentioned goes in the summary as a follow-up, unless the requested behaviour cannot work without it. Commit tests only where the task asks for them or the repo already keeps tests for that kind of change, sized like the neighbouring test files. Scratch checks stay scratch.
- Web search and URL fetches go through the Exa MCP. Anything newer than your training data gets searched, not recalled; a name you only half-recognize from a fast-moving area (AI models, developer tools) is a search too, with the name as I wrote it in at least one query. To scope results to specific sites or dates, use `web_search_advanced_exa` and its domain/date filters instead of typing `site:` into the query. `web_fetch_exa` takes a `urls` array, not `url`; raise `maxCharacters` when reading full docs pages.

## Models

Pick the Claude model and effort for the session and each subagent yourself. fable-5.1 and `xhigh`/`max` effort burn through my Claude limits fastest, so they run only when I ask.

- Reviews of a plan or implementation, when I ask for one: fable-5.1, gpt-6-astra, or gpt-6.1-sol, at `high`.
- Non-Claude models run only when I name them. Codex models go through `delegate_task` inside T3 Code and the Codex CLI everywhere else; read `~/.claude/codex.md` before any CLI call. Set the reasoning effort explicitly either way, since the defaults don't match mine.
