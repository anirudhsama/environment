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

On either platform, move existing Bash startup files aside before the first
bootstrap so mise can link the tracked versions:

```sh
for file in ~/.bashrc ~/.bash_profile; do
  if [ -f "$file" ] && [ ! -L "$file" ]; then
    mv "$file" "$file.pre-environment"
  fi
done
mise bootstrap
```

Keep machine-specific Bash additions in `~/.bashrc.local`. Both platforms load
mise shims for `bash -lc`; interactive Bash uses full mise activation. Fish
also uses shims for noninteractive commands, including macOS SSH sessions.
Child processes inherit PATH. An independently launched `bash -c` with a bare
environment reads neither Bash file; use `bash -lc` or `mise exec --` there.

Linux keeps Bash as the account login shell because VS Code and T3 Code Remote
SSH send a Bash bootstrap script through a non-interactive SSH session. The
tracked `.bash_profile` switches interactive terminal logins to fish, so SSH,
Mosh, and local TTY sessions still open in fish. macOS uses fish directly.

Install mise from `mise.run`, **not** brew or pacman — it's the only route that
enables `mise self-update`, and mise ships near-daily so every distro lags it.

`mise bootstrap` converges: re-run it after every pull. `--dry-run` to preview,
`mise bootstrap status` to inspect.

## Where software comes from

1. **OS package** (`[bootstrap.packages]`) when it exists and tracks upstream —
   on Arch that's nearly everything, and it brings completions and manpages.
2. **mise `[tools]`** when it isn't packaged, the distro lags, or it's npm-only.
3. **A vendor self-updater** only where lifecycle semantics require it: herdr's
   live handoff, and mise itself.

Claude and Codex use the same mise backends selected by Omarchy. OpenCode 2,
Grok, and Pi come from npm through mise, because Omarchy's OpenCode backend only
ships V1. All of them are declared in the tracked global mise config.

`update` on the devbox refreshes all three.

## Android and device pool

Every machine builds Android; only dev-mbp-14 runs devices.

| Machine | Android SDK | Simlock |
|---|---|---|
| M5 (`anirudhs-mbp-14`) | `scripts/android-sdk` | client |
| devbox | `scripts/android-sdk` | gateway, `https://devbox.<tailnet>.ts.net:8443` |
| `dev-mbp-14` | `scripts/android-sdk --device-host` | worker: iOS simulators and Android emulators |

- **Paths.** `ANDROID_HOME`, `ANDROID_SDK_ROOT` and `JAVA_HOME` are set in both
  `.bashrc` (for `bash -lc`) and `config.fish`, and `~/.androidrc` (linked per
  platform) points Android CLI at the same SDK with metrics off.
- **Android CLI** comes from mise. `bootstrap-common` runs `android init`. The
  skill copy it writes under `~/.agents/skills` is gitignored.
- **Simlock** comes from mise and runs as its own login service
  (`simlock daemon install`). `scripts/simlock-services` re-installs it when a
  Node or simlock upgrade breaks the saved paths. The gateway and worker roles
  are set up by hand once, because join tokens are secrets:

  ```sh
  # devbox
  simlock --gateway daemon start
  for c in stream input agent-device; do simlock --gateway config set capabilities.$c.enabled true; done
  simlock --gateway config set lease.maxPerRequester '{"ios":2,"android":2}'
  simlock --gateway config set update.check false   # its npm lookup trips on mise's npm wrapper
  simlock --gateway token create --role worker --label dev-mbp-14
  simlock --gateway token create --role agent --label <t3-server>   # one per T3 server
  mise bootstrap                 # Tailscale Serve on :8443, systemd user unit

  # dev-mbp-14 (stay logged in at the screen: the LaunchAgent needs a GUI session)
  simlock config set gateway '{"url":"wss://devbox.<tailnet>.ts.net:8443","token":"slk_…","label":"dev-mbp-14"}'
  for c in stream input agent-device; do simlock config set capabilities.$c.enabled true; done
  # mise's .bin/agent-device is a wrapper script, which Simlock can't trace to its package.json
  simlock config set capabilities.agent-device.command ~/.local/share/mise/installs/npm-agent-device/latest/node_modules/agent-device/bin/agent-device.mjs
  # Two Android cold boots at once on the M1 Pro both miss the 180 s boot timeout
  simlock config set warmPool.maxConcurrentBoots 1
  simlock config set android.emulator.gpu host
  simlock config set update.check false
  mise bootstrap                 # LaunchAgent
  ```

  Token secrets live in `~/.config/simlock/tokens/<label>` on the devbox (mode 600).

  In T3: Settings → Labs → Simlock device hosts, then Settings → Devices → Add
  source → Simlock pool, with the gateway URL and that server's agent token.

## Machine-local files (never committed)

| File | Holds |
|---|---|
| `~/.config/fish/local.fish` | secrets & host-specific fish (psql connection functions on the Mac) |
| `~/.gitconfig.local` | commit signing program, `commit.gpgsign`, maintenance repos |
| `~/.claude/settings.local.json` | machine-local Claude Code settings |
| `~/.codex/config.toml` | Codex rewrites this at runtime; seed from `home/.codex/config.toml.example` |
| `~/.codex/auth.json`, `~/.local/share/atuin/key` | credentials — back up via 1Password, not git |
| `~/.config/opencode/serve.env` | devbox OpenCode server password; `bootstrap-linux` generates it if missing |
| `~/.simlock/` | Simlock state, config and tokens; the worker's join token sits in `config.json` |

## Notes

- `mode = "symlink-each"` creates real directories and symlinks each file
  individually, so runtime state (claude sessions, `fish_variables`, lazy
  plugins) lands beside the tracked configs rather than inside the repo.
- `~/.agents/skills` is a whole-directory `symlink` instead: Codex rejects
  skills whose `SKILL.md` is a file symlink. The dir link keeps skill files
  real; `~/.agents` itself stays a real directory for untracked state.
- `auto_env` must live in `.miserc.toml`. mise picks its config files before
  reading settings out of them, so setting it under `[settings]` is silently
  ignored. It becomes the default in mise 2027.6.0.
- `= "latest"` means "newest at install time", not "always newest" — an
  installed version satisfies it. `mise upgrade` is what moves tools forward.
  The coding agents, eas-cli, vercel, agent-browser and hunk are the exception:
  they set `auto_update`, and the `mise-tool-update` service upgrades them in
  the background once a day. While
  it runs, launches never update in the foreground. `mise bootstrap services
  status` shows it; `mise doctor` shows the last failed update.
- The devbox OpenCode server (`dev.mise.opencode.service`) listens on the
  Tailscale address at port 4096 as the shared background service
  (`serve --service`), so `opencode pair` and the apps' pairing codes work.
  OpenCode 2 can't run without a password and invents a new one on first
  start, so the unit copies a fixed one from `serve.env` into the service
  config before each start. Manual clients use username `opencode` and that
  password.
- The DevboxDrop LaunchAgent stays a hand-written plist: it's `WatchPaths`
  driven and mise's launchd schema has no `WatchPaths`/`ThrottleInterval`.
- Lean reference clones live in `~/code/references` (effect, opencode, t3code),
  maintained by `sync-reference-repos`. Bootstrap populates them; a daily
  systemd timer (Linux) / launchd agent (macOS) refreshes them. Not
  `[bootstrap.repos]` — mise can't do `--depth 1`.
- Fish plugins are fisher-managed and untracked; `fish_plugins` is the lockfile.
  Neovim restores from `lazy-lock.json` on first launch.
- macOS Homebrew packages are a curated counterpart to the Arch package set;
  Apple-provided and Linux-only tools are intentionally omitted.
