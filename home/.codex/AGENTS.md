## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background: skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, cut the preamble, and keep comments to the ones that earn their place.
- Bias toward prose unless we are actively implementing, debugging, reviewing, or prototyping code, or I explicitly ask for snippets. In brainstorming, design discussion, planning, tradeoff analysis, product thinking, and architecture conversations, do not pad the response with code examples.
- Scope is the request. A pre-existing bug, a perf concern, or behaviour the task never mentioned goes in the summary as a follow-up, unless the requested behaviour cannot work without it. Commit tests only where the task asks for them or the repo already keeps tests for that kind of change, sized like the neighbouring test files. Scratch checks stay scratch.

## Machines

These computers use the `emperor-jazz.ts.net` Tailscale tailnet:

| Names I use | Tailnet DNS | Access from primary Mac | Environment checkout |
|---|---|---|---|
| main Mac, primary Mac, M5 MacBook Pro | `anirudhs-mbp-14.emperor-jazz.ts.net` | Local machine | `~/Documents/code/environment` |
| devbox, Linux box | `devbox.emperor-jazz.ts.net` | `ssh devbox` | `~/dev/environment` |
| Dev Mac, development Mac, old MacBook Pro | `dev-mbp-14.emperor-jazz.ts.net` | `ssh dev-mbp-14` | `~/Documents/code/environment` |

When I assign work to a named machine, run it on that machine in the checkout above. From the primary Mac, use the short SSH target directly. If the session is already running on the target machine, work locally.

## Sideshow Visuals

Use Sideshow by default for visual deliverables: UI mockups, HTML pages, dashboards, charts, diagrams, rendered explanations, presentations, and screenshots. Local Markdown, HTML, SVG, image files, code, or prose stand in only when I explicitly ask for them. If Sideshow is unavailable, say so and ask which fallback I want rather than writing a file.

Explicit requests to implement repository files are exempt; use Sideshow for visual review when relevant.
