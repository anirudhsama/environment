# environment

Dotfiles + devbox provisioning, [thdxr/environment](https://github.com/thdxr/environment)-style.

| | |
|---|---|
| `mise.toml` | shared provisioning: dotfiles and the convergence task |
| `mise.linux.toml` / `mise.macos.toml` | per-platform: packages, dotfiles, services, login shell |
| `.miserc.toml` | `auto_env`, which is what loads the two files above |
| `home/` | mirror of `~`, symlinked in by `[dotfiles]` |
| `home/.config/mise/config.toml` | global tools — runtimes and cross-machine CLIs |
| `scripts/` | the non-declarative convergence steps |
| `bootstrap/` | Arch devbox first-boot, root-only. Never run on the Mac |

## New machine

```sh
curl https://mise.run | sh
git clone https://github.com/<you>/environment ~/dev/environment
cd ~/dev/environment && mise trust . && mise bootstrap
```

If `~/.bashrc` already exists, move it aside before the first bootstrap so
mise can link the tracked Linux version:

```sh
mv ~/.bashrc ~/.bashrc.pre-environment
mise bootstrap
```

Install mise from `mise.run`, **not** brew or pacman — it's the only route that
enables `mise self-update`, and mise ships near-daily so every distro lags it.

`mise bootstrap` converges: re-run it after every pull. `--dry-run` to preview,
`mise bootstrap status` to inspect.

## Where software comes from

1. **OS package** (`[bootstrap.packages]`) when it exists and tracks upstream —
   on Arch that's nearly everything, and it brings completions and manpages.
2. **mise `[tools]`** when it isn't packaged, the distro lags, or it's npm-only.
3. **A vendor self-updater**, only where the vendor recommends it: claude-code,
   herdr, and mise itself.

`update` on the devbox refreshes all three.

## Machine-local files (never committed)

| File | Holds |
|---|---|
| `~/.config/fish/local.fish` | secrets & host-specific fish (psql connection functions on the Mac) |
| `~/.gitconfig.local` | commit signing program, `commit.gpgsign`, maintenance repos |
| `~/.claude/settings.local.json` | machine-local Claude Code settings |
| `~/.codex/config.toml` | Codex rewrites this at runtime; seed from `home/.codex/config.toml.example` |
| `~/.codex/auth.json`, `~/.local/share/atuin/key` | credentials — back up via 1Password, not git |

## Notes

- `mode = "symlink-each"` creates real directories and symlinks each file
  individually, so runtime state (claude sessions, `fish_variables`, lazy
  plugins) lands beside the tracked configs rather than inside the repo.
- `auto_env` must live in `.miserc.toml`. mise picks its config files before
  reading settings out of them, so setting it under `[settings]` is silently
  ignored. It becomes the default in mise 2027.6.0.
- `= "latest"` means "newest at install time", not "always newest" — an
  installed version satisfies it. `mise upgrade` is what moves tools forward.
- The DevboxDrop LaunchAgent stays a hand-written plist: it's `WatchPaths`
  driven and mise's launchd schema has no `WatchPaths`/`ThrottleInterval`.
- Fish plugins are fisher-managed and untracked; `fish_plugins` is the lockfile.
  Neovim restores from `lazy-lock.json` on first launch.
- Homebrew packages aren't declared yet — the Mac's package set is still
  unmanaged. `mise bootstrap packages import` will seed the formulae list.
