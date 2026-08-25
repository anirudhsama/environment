# Coding agent installation channels

Checked on 2026-08-25. Versions are a point-in-time snapshot because all three projects release frequently.

## Repository decision

Use Omarchy's bare mise aliases for Claude Code, Codex, and OpenCode, with the
agents declared normally in the tracked global mise config rather than hidden
behind launch-time wrappers. Grok uses Omarchy's explicit
`npm:@xai-official/grok` backend. This keeps every machine on the same sourcing
policy and makes bootstrap and `mise upgrade` the convergence points.

The freshness comparison below originally favored explicit GitHub backends:

Move Claude Code, Codex, and OpenCode to mise, but declare explicit release backends instead of copying Omarchy's bare shorthands:

```toml
[tools]
"github:anthropics/claude-code" = "latest"
"github:openai/codex" = "latest"
"github:anomalyco/opencode" = "latest"
```

At the time of this check, those three declarations resolved to the newest upstream releases: Claude Code 2.1.245, Codex 0.149.1, and OpenCode 1.18.23. Mise's GitHub backend reads release metadata directly and selects the platform asset. It also avoids Node and a second OS package-manager policy for the agents. See the [mise GitHub backend documentation](https://mise.jdx.dev/dev-tools/backends/github.html).

This changes update ownership. Claude's native installer updates itself in the background, while a mise-managed Claude updates when `mise up` or the repository bootstrap runs. Anthropic says package-manager installations do not use Claude's own auto-updater. The native and npm installers deliver the same native executable. See [Anthropic's installation documentation](https://code.claude.com/docs/en/installation).

The repository deliberately accepts the small registry-snapshot lag measured
below in exchange for matching Omarchy's selected and tested backends. Do not
keep Homebrew, Bun-global, or native copies alongside them; multiple copies make
PATH order decide which version runs.

## Freshness snapshot

| Agent | Upstream latest | Bare mise shorthand | Explicit mise `github:` | Homebrew | Main Mac | `dev-mbp-14` |
|---|---:|---:|---:|---:|---:|---:|
| Claude Code | 2.1.245 | 2.1.241 | 2.1.245 | `claude-code@latest` 2.1.243; stable cask 2.1.231 | 2.1.239, native | 2.1.245, native |
| Codex | 0.149.1 | 0.149.1 | 0.149.1 | cask 0.149.1 | 0.149.0, Homebrew cask | 0.149.1, Bun global |
| OpenCode | 1.18.23 | 1.18.22 | 1.18.23 | vendor tap 1.18.23; Homebrew core 1.18.20 | 1.18.21, native | 1.18.23, Bun global |

Upstream release evidence:

- [Claude Code 2.1.245 release](https://github.com/anthropics/claude-code/releases/tag/v2.1.245), published 2026-08-25.
- [Codex 0.149.1 release](https://github.com/openai/codex/releases/tag/rust-v0.149.1), published 2026-08-24.
- [OpenCode 1.18.23 release](https://github.com/anomalyco/opencode/releases/tag/v1.18.23), published 2026-08-25.
- The live [Homebrew Claude cask](https://formulae.brew.sh/api/cask/claude-code.json), [Claude latest-channel cask](https://formulae.brew.sh/api/cask/claude-code@latest.json), [Codex cask](https://formulae.brew.sh/api/cask/codex.json), and [OpenCode core formula](https://formulae.brew.sh/api/formula/opencode.json) supplied the Homebrew versions above.
- OpenCode's vendor tap was already at 1.18.23 in its [official tap formula](https://github.com/anomalyco/homebrew-tap/blob/master/opencode.rb).

The current-machine versions came from each binary's `--version` output over local execution and SSH. They are observations, not repository state.

## What mise actually installs

Mise 2026.8.12 maps the short names as follows:

- `claude` selects `aqua:anthropics/claude-code` first, with `http:claude` as a fallback. See the [mise Claude registry entry](https://github.com/jdx/mise/blob/v2026.8.12/registry/claude.toml).
- `codex` selects `aqua:openai/codex` first, with `npm:@openai/codex` second. See the [mise Codex registry entry](https://github.com/jdx/mise/blob/v2026.8.12/registry/codex.toml).
- `opencode` selects `aqua:anomalyco/opencode`. See the [mise OpenCode registry entry](https://github.com/jdx/mise/blob/v2026.8.12/registry/opencode.toml).

Mise bundles tested snapshots of its shorthand and Aqua registries by default. That explains the small lag in bare `claude` and `opencode` today. Mise documents `registry_floating=true` for fresher registry data, but explicit `github:` declarations are simpler here and bypass shorthand snapshot timing. See the [mise registry documentation](https://mise.jdx.dev/registry) and [Aqua backend documentation](https://mise.jdx.dev/dev-tools/backends/aqua.html).

The npm backends are equally fresh in this snapshot:

| Declaration | Resolved version |
|---|---:|
| `npm:@anthropic-ai/claude-code` | 2.1.245 |
| `npm:@openai/codex` | 0.149.1 |
| `npm:opencode-ai` | 1.18.23 |

Mise's npm backend no longer requires an installed Node or npm executable. It resolves and installs packages itself. The [mise 2026.7.12 release notes](https://github.com/jdx/mise/releases/tag/v2026.7.12) document that change. Using `github:` is still the cleaner choice for these three because they all publish native release assets.

## Vendor and Homebrew channels

Claude Code's native installer is the strongest alternative to mise. It follows Anthropic's `latest` or `stable` channel and auto-updates. Moving it to mise trades that background updater for one shared manifest and one update command. The installed payload remains a native executable. [Anthropic documents the native, Homebrew, Linux package, and npm channels](https://code.claude.com/docs/en/installation).

OpenAI supports its standalone installer, npm, Homebrew cask, and direct GitHub release binaries. The current Homebrew cask matched the GitHub and npm release within about 22 minutes. See the [official Codex repository installation section](https://github.com/openai/codex#installing-and-running-codex-cli).

OpenCode recommends its own Homebrew tap over Homebrew core because the tap updates faster. It also documents mise and direct release installation. In this snapshot the tap and explicit mise backends were current, while core was three patch releases behind. See the [OpenCode install documentation](https://opencode.ai/docs#install).

## What Omarchy does now

Omarchy `quattro` at commit [`4637735`](https://github.com/basecamp/omarchy/commit/4637735aa2e98851c68429df1a71b6c361760609) installs `mise-bin` as a base Arch package, then creates lazy mise wrappers for all three agents:

- [`install/omarchy-base.packages`](https://github.com/basecamp/omarchy/blob/4637735aa2e98851c68429df1a71b6c361760609/install/omarchy-base.packages) includes `mise-bin`.
- [`install/user/mise.sh`](https://github.com/basecamp/omarchy/blob/4637735aa2e98851c68429df1a71b6c361760609/install/user/mise.sh) calls `omarchy-mise-install codex`, `omarchy-mise-install claude`, and `omarchy-mise-install opencode`.
- [`bin/omarchy-mise-install`](https://github.com/basecamp/omarchy/blob/4637735aa2e98851c68429df1a71b6c361760609/bin/omarchy-mise-install) writes a small launcher under `~/.local/bin`. Every launch sets `MISE_MINIMUM_RELEASE_AGE=0`, runs `mise use -g --quiet <name>`, then executes that mise tool.
- [`bin/omarchy-update-mise`](https://github.com/basecamp/omarchy/blob/4637735aa2e98851c68429df1a71b6c361760609/bin/omarchy-update-mise) runs `MISE_MINIMUM_RELEASE_AGE=0 mise up` as part of `omarchy update`.

The wrappers make installation lazy and make every launch an update check. `MISE_MINIMUM_RELEASE_AGE=0` disables mise's release cooldown. It does not make a bundled Aqua registry snapshot see a release that the snapshot does not contain. That is why Omarchy's current bare shorthands resolved to Claude 2.1.241 and OpenCode 1.18.22 during this check, even though the explicit GitHub backends saw 2.1.245 and 1.18.23.

For this environment repo, persistent `[tools]` declarations plus the existing bootstrap are enough. Omarchy's per-command wrapper is useful for a desktop distribution that wants lazy installs. It adds little here because these agents should exist on every development machine.
