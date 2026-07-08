# environment

Dotfiles + devbox provisioning, [thdxr/environment](https://github.com/thdxr/environment)-style.

- `home/` — mirror of `~`, symlinked in with GNU Stow. Fish, Neovim (LazyVim),
  Ghostty, git, mise, atuin, Claude Code, Codex.
- `bootstrap/` — Arch devbox provisioning (CloudPe). Never run on the Mac.
- `install` — make this machine match the repo. Idempotent; run after every pull.

## New machine

```sh
git clone https://github.com/<you>/environment ~/dev/environment
~/dev/environment/install
```

`install` stows `home/` into `~` (`--no-folding`, so runtime state stays out of
the repo), bootstraps fisher + fish plugins from `fish_plugins`, and runs
`mise install` (node, bun, fnox, ...).

## Machine-local files (never committed)

| File | Holds |
|---|---|
| `~/.config/fish/local.fish` | secrets & host-specific fish (psql connection functions live here on the Mac) |
| `~/.gitconfig.local` | commit signing program, `commit.gpgsign`, maintenance repos |
| `~/.claude/settings.local.json` | machine-local Claude Code settings |
| `~/.codex/config.toml` | Codex runtime config; start from `home/.codex/config.toml.example` |
| `~/.codex/auth.json`, `~/.local/share/atuin/key` | credentials — back up via 1Password, not git |

## Notes

- Codex rewrites `~/.codex/config.toml` at runtime (project trust, hook trust,
  UI state), so the live file is ignored. Keep durable defaults in
  `home/.codex/config.toml.example`.
- `install` uses `bunx add-mcp` to install common MCP servers globally for
  Claude Code and Codex only.
- Fish plugin files (`conf.d/z.fish`, tide, fzf functions, themes) are
  fisher-managed and intentionally untracked — `fish_plugins` is the lockfile.
- Neovim plugins restore from `lazy-lock.json` on first launch
  (or `nvim --headless '+Lazy! restore' +qa`).
