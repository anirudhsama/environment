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

Keep machine-specific Bash additions in `~/.bashrc.local`. Bash always loads
mise shims. Fish activates mise only in a terminal (interactive with a TTY) and
uses shims otherwise, including macOS SSH sessions. T3 Code reads PATH from an
interactive login shell without a TTY and keeps it, so it gets shims, which
survive `mise upgrade`; that is what lets its Update run `mise upgrade`.
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
ships V1. Antigravity (`agy`) is Google's native release binary through mise,
with its self-updater off so mise owns upgrades. All of them are declared in the
tracked global mise config.

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
- **Android CLI** comes from mise. Bootstrap does not run `android init`: its
  skill would be written untracked into every agent's skill folder. Add it
  through the tracked skills instead if it's wanted.
- **Simlock** comes from mise, and mise runs it: the gateway as the
  `dev.mise.simlock-gateway` systemd unit (`mise.linux.toml`), the worker as
  the `dev.mise.simlock-worker` LaunchAgent from the `simlock-worker` machine
  module (`mise.simlock-worker.toml`), which only dev-mbp-14 selects. Manage
  them with `systemctl --user` / `launchctl`, not `simlock daemon
  start|stop|install`: those start a second, unmanaged daemon or install
  Simlock's own unit beside mise's. Settings are tracked; join tokens are
  secrets, so they are created and placed by hand once:

  ```sh
  # devbox
  mise bootstrap                 # gateway unit and settings, Tailscale Serve on :8443
  # The secret is printed once; the gateway keeps only its id and label.
  mkdir -p ~/.config/simlock/tokens
  token() { (umask 077; simlock --gateway token create --role "$1" --label "$2" | jq -r .secret > ~/.config/simlock/tokens/"$2"); }
  token worker dev-mbp-14
  for t3 in t3-m5 t3-devbox t3-dev-mbp-14; do token agent "$t3"; done   # one per T3 server
  systemctl --user restart dev.mise.simlock-gateway

  # dev-mbp-14 (stay logged in at the screen: the LaunchAgent needs a GUI session)
  echo 'env = ["simlock-worker"]' >> ~/.config/mise/miserc.local.toml
  mise bootstrap                 # worker settings, LaunchAgent (fails to start until the token is set)
  # The only setting not in the repo; Simlock refuses it before gateway.url is set
  simlock config set gateway.token slk_…
  launchctl kickstart -k gui/$(id -u)/dev.mise.simlock-worker
  ```

  **Settings** live in `home/.simlock/gateway/config.json` (gateway, merged
  from `mise.linux.toml`) and `home/.simlock/config.json` (worker, merged from
  `mise.simlock-worker.toml`). `mise bootstrap` merges each into Simlock's own
  config file as a dotfiles `merge` entry: mise owns those keys and leaves the
  rest, the worker's token included, alone. To change one, edit the repo file,
  run `mise bootstrap`, then restart that daemon; a `simlock config set` on an
  owned key is reverted by the next bootstrap. Why some values are set:

  - `capabilities.agent-device.command` points at the package's script,
    since mise's `.bin/agent-device` is a wrapper Simlock can't trace to its
    `package.json`. It goes through `~/.simlock/pinned-agent-device`, which
    the LaunchAgent points at the pinned install (`mise where`) on every
    start.
  - `warmPool.maxConcurrentBoots` is 1 because two Android cold boots at once
    on this M1 Max both miss the 180 s boot timeout.
  - `update.check` is off on both because Simlock's npm lookup trips on mise's
    npm wrapper.
  - `ios.defaultMode` is `slim`. Simlock clones every iOS lease from a stored
    seed in `~/.simlock/devices/ios/sources`, and in slim mode writes
    simslim's launchd overrides into the clone before its first boot. A fresh
    iPhone 17 Pro on iOS 27 comes up at about 3.4 GB instead of 6.9 GB.
    `ios.slim.categories` leaves out `store` (push, StoreKit), `web`
    (universal links), `photos` and `pim`. Slim still breaks StoreKit
    (`icloud` and `other` stop the AMS and Wallet daemons it needs), widgets
    and Live Activities, and iCloud Keychain; lease with `--mode full` for
    those. After changing the mode, `simlock warm forget ios <model> 27.0
    --mode <old>` so the warm pool stops keeping devices of the old mode.

  **Upgrading.** The gateway and worker must run the same protocol, so bump
  `npm:simlock` in the global mise config, then on both machines run
  `mise bootstrap` and restart the daemon: `systemctl --user restart
  dev.mise.simlock-gateway` on the devbox, `launchctl kickstart -k
  gui/$(id -u)/dev.mise.simlock-worker` on dev-mbp-14. The units resolve
  the pinned simlock and agent-device with `mise where` when they start, so
  a bump takes effect at the restart, and an extra installed version changes
  nothing. Nothing restarts them on its own. A restart ends running leases.

  **agent-device ahead of Simlock.** T3 Nightly pins agent-device 0.21.41,
  which speaks daemon RPC protocol 3. Simlock 0.8.0 (the newest release, and
  upstream `main`) only accepts protocol 2: its worker refuses a protocol-3
  agent-device, and its bundled `@agent-device/proxy` 0.21.36 reports
  protocol 2, which T3's client refuses. Until a Simlock release accepts
  protocol 3, the worker's simlock 0.8.0 install on dev-mbp-14 is patched by
  hand; the devbox gateway runs stock. In
  `~/.local/share/mise/installs/npm-simlock/0.8.0/node_modules/.mise/`:

  - `@agent-device+proxy@0.21.36/node_modules/@agent-device/proxy` holds
    `@agent-device/proxy` 0.21.41's `package.json` and `dist/` (it has no
    dependencies). The original is in `~/.simlock/proxy-0.21.36.bak`.
  - `simlock@0.8.0/node_modules/simlock/dist/agent-device/shared/compatibility.js`
    sets `AGENT_DEVICE_RPC_PROTOCOL_VERSION = 3`. The original is in
    `~/.simlock/compatibility.js.bak`.

  Reinstalling simlock 0.8.0 drops both patches. Check with `curl -s -H
  "Authorization: Bearer $(cat ~/.config/simlock/tokens/t3-devbox)"
  http://127.0.0.1:4700/v1/agent-device/health` on the devbox: the proxy and
  its upstream should both report `"rpcProtocolVersion":3`. Once a Simlock
  release accepts protocol 3, bump `npm:simlock` and drop this section.

  Token secrets live only in `~/.config/simlock/tokens/<label>` on the devbox
  and where they are used: the worker's `~/.simlock/config.json` and each T3
  server's settings. A lost or leaked token is replaced, not recovered:
  `simlock --gateway token list`, `token revoke <id>`, then create a new one.

  If the worker logs `Skipped Android driver: adb server unavailable`,
  something else holds Simlock's adb port (5038), often an adb server that
  surviving emulators restarted. Stop that listener and any leftover
  `qemu-system` emulators, then restart the worker.

  In T3: Settings → Labs → Simlock device hosts, then Settings → Devices → Add
  source → Simlock pool, with the gateway URL and that server's agent token.

## Rex

The devbox runs [Rex](https://www.superlogical.com/rex/docs/linux/installation)
from Superlogical's pacman repo, preview channel. `bootstrap-linux` adds the
repo and its key, installs `rex` once (`update` upgrades it with the system),
and runs `rex server install`, which enables the package's `rex.socket` user
unit. With linger on, the personal server starts at boot or on first use and
keeps running while logged out. Package upgrades don't restart it; it picks up
a new version at the next reboot or `systemctl --user restart rex.service`.

Clients connect over SSH: `ssh://ani@devbox` on the Mac (Add Remote Host…, or
`rex -S ssh://ani@devbox ls`) and `ssh://ani@devbox.<tailnet>.ts.net` on
iPhone/iPad, whose own SSH client doesn't read `~/.ssh/config`. Tailscale SSH
answers port 22 on the tailnet, so access follows the tailnet SSH policy, not
`authorized_keys`; that policy should `accept` your own devices, because a
`check` re-auth prompt stalls Rex reconnects. dev-mbp-14 is reached through its
Rex app's built-in Tailscale instead.

On the Mac, `rex` ships only inside the app bundle; `config.fish` and
`.bashrc` put it on PATH. `bootstrap-common` runs `rex skill setup` on both
machines: the Rex skill for Claude Code, Codex, OpenCode, and Pi, plus
session-start hooks for Claude Code and Codex (Codex asks you to approve its
hook once, with `/hooks`). Agents started outside Rex still get the skill.

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
| `~/.config/mise/miserc.local.toml` | this machine's mise modules (`env = ["simlock-worker"]` on dev-mbp-14) |

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
  The coding agents, eas-cli, vercel, agent-browser, browse and hunk are the exception:
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
- browse (the Chrome extension's MCP server) is Mac-only. Each Mac's agents use
  that Mac's own Chrome through a local relay; the extension arrives by Chrome
  Sync, but each Mac pairs once by hand: `browse pair`, then enter the code
  under the extension's Options → Pairing code. Restart agents after the first
  `mise bootstrap` so they load the MCP server.
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
