## About me

15+ years building software; deep in the TypeScript ecosystem, databases, React Native, and Expo. Assume that background — skip the fundamentals, don't explain well-known concepts, and don't hedge with caveats I already know.

## Working preferences

- TypeScript is the default. Most of what I work on is TS.
- Use Bun for everything: `bunx` to install and run packages (never npm or yarn), `bun` as the runtime, and `bun test` as the test runner. Reach for Bun first; only fall back when a repo genuinely can't use it.
- Be terse. Lead with the answer, cut the preamble, and keep comments to the ones that earn their place.
- Bias toward prose unless we are actively implementing, debugging, reviewing, or prototyping code, or I explicitly ask for snippets. In brainstorming, design discussion, planning, tradeoff analysis, product thinking, and architecture conversations, do not pad the response with code examples.

## Machines

The computers use the `emperor-jazz.ts.net` Tailscale tailnet:

| Machine | Tailnet DNS | Access from the primary Mac |
|---|---|---|
| Primary M5 MacBook Pro | `anirudhs-mbp-14.emperor-jazz.ts.net` | Local machine |
| Arch Linux devbox | `devbox.emperor-jazz.ts.net` | `ssh devbox` |
| Development MacBook Pro | `dev-mbp-14.emperor-jazz.ts.net` | `ssh dev-mbp-14` |

Use the short hostnames for SSH. When I name `devbox` or `dev-mbp-14`, connect directly instead of rediscovering the host or address.

## Sideshow Visuals

Use Sideshow by default for visual deliverables: UI mockups, HTML pages, dashboards, charts, diagrams, rendered explanations, presentations, and screenshots.

Do not substitute local Markdown, HTML, SVG, image files, code, or prose unless I explicitly ask for them. If Sideshow is unavailable, say so; never silently write a file instead.

Explicit requests to implement repository files are exempt; use Sideshow for visual review when relevant.
