# environment

Dotfiles + devbox provisioning, [thdxr/environment](https://github.com/thdxr/environment)-style.

| | |
|---|---|
| `mise.toml` | shared provisioning: dotfiles, shell activation, the convergence task |
| `mise.linux.toml` / `mise.macos.toml` | per-platform: packages, systemd units, login shell |
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
| `~/.bashrc` | the two machines share nothing in it; mise maintains only its own block |
| `~/.codex/auth.json`, `~/.local/share/atuin/key` | credentials — back up via 1Password, not git |

## Notes

- `mode = "symlink-each"` is the old `stow --no-folding` behaviour: real
  directories, per-file symlinks, so runtime state lands beside the tracked
  configs rather than inside the repo. Stow is no longer used.
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

## Migrating an existing machine

One-time, on a machine with the old stow layout. **Do step 1 first**: the
systemd units reference `%h/.local/bin/mise`, so converging earlier leaves them
pointing at a binary that doesn't exist.

```sh
# 1. mise off the package manager. Confirm the new one runs before removing
#    the old, so you're never without a working mise.
curl https://mise.run | sh
~/.local/bin/mise --version
brew uninstall mise          # Mac
sudo pacman -R mise          # devbox
hash -r && which mise && mise self-update -y

# 2. drop the stow symlinks — mise re-creates them
stow -D -t ~ home

# 3. devbox: retire the pre-mise units. mise namespaces its own as
#    dev.mise.<name>.service, so these would otherwise keep running.
#    paseo is dropped for good.
systemctl --user disable --now opencode t3-code taildrop-inbox paseo
rm -f ~/.config/systemd/user/{opencode,t3-code,taildrop-inbox,paseo}.service
systemctl --user daemon-reload

# 4. devbox: claude-code moves to its native installer
paru -Rns claude-code

# 5. converge, then take uv off its stale pinned version
mise bootstrap
mise upgrade uv
```

Then trim the devbox's `~/.bashrc`: drop the duplicate `ANDROID_HOME` block
(`mise env` no longer exports any `ANDROID_*`) and the `ls`/`grep` aliases and
`PS1`, which never run under fish. Keep the first `ANDROID_HOME` block so bash
still sees the SDK — fish gets it from `config.fish` now.

The AUR packages this retires — `bun-bin`, `claude-code`, `doppler-cli-bin`,
`hasura-cli-bin`, `opencode-bin`, `openai-codex-bin` — can go once
`mise bootstrap` has installed their replacements. Keep paru itself as a `-Syu`
wrapper and escape hatch; nothing in provisioning needs it.
