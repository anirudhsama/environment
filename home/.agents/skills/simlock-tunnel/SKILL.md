---
name: simlock-tunnel
description: Reach Metro and local backends from a Simlock device over an SSH reverse tunnel. Use when a leased simulator or emulator on dev-mbp-14 must load its bundle or call dev servers running on the devbox or the M5.
---

Simlock devices run on `dev-mbp-14`. Metro and any local backends run wherever the session runs. When the session is on `dev-mbp-14` itself, they are already on the device's `localhost`: skip the tunnel.

Reach them through an **SSH reverse tunnel** so the device loads everything from `localhost`. iOS App Transport Security allows plain `http` only to `localhost`, so this works for every app and needs no HTTPS or public exposure. It is also faster than routing over the tailnet.

Forward each port **on the same number** on both sides. Dev builds bake backend URLs in as `http://localhost:<port>`, and a URL keeps its port wherever it is loaded.

## Steps

1. **Collect the ports.** Metro's port, plus the port of every local backend the app will call. Leave out backends the app won't call, for example when it points at a deployed preview. In speak, `bun run mobile <app> dev --dry-run` prints the worktree's ports (`metro`, `next`, `workers-api`). Forward `next` and `workers-api` whenever the app uses local backends, including with `--no-backends` while another app in the worktree runs them. The main checkout uses the defaults (8081, 3000, 8787), which may be taken on the Mac. `SPEAK_PORT_SLOT=<n>` pins a free block.
2. **Start the stack** in the background with output to a log, with `EXPO_PACKAGER_PROXY_URL=http://localhost:<metro>` set so the manifest advertises the Mac's `localhost`. Done when the log shows Metro listening on its port.
3. **Open the tunnel** in the background, with one `-R` per port:
   ```sh
   ssh -o BatchMode=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N \
     -R 127.0.0.1:<metro>:127.0.0.1:<metro> -R 127.0.0.1:<next>:127.0.0.1:<next> … dev-mbp-14
   ```
   If it exits right away, a port is busy on the Mac: pick another block and restart the stack.
4. **Verify from the Mac and warm the bundle.** Done when all of these hold:
   - `ssh dev-mbp-14 'curl -s http://127.0.0.1:<metro>/status'` prints `packager-status:running`.
   - Every forwarded backend port answers an HTTP request from the Mac.
   - The manifest (`curl -s -H 'expo-platform: ios' -H 'Accept: application/expo+json,application/json' http://localhost:<metro>/`, run on the Mac) shows a bundle `url` on `http://localhost:<metro>`, and curling that bundle URL once returns 200. The first build takes about 35 s, longer than the dev client waits, so warm it before launching.
5. **Launch through `agent-device`** (from `device_open`), pointing the dev client at the tunnel. The scheme is `exp+<slug>`, with the slug from the app's `app.json` / `app.config`:
   ```sh
   agent-device open <bundle-id> --relaunch \
     --launch-url "exp+<slug>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A<metro>" \
     --metro-host localhost --metro-port <metro>
   ```
   **Android:** the emulator's `localhost` is the emulator, so first run `adb -s <serial> reverse tcp:<port> tcp:<port>` on `dev-mbp-14` for every forwarded port. `bun run mobile` only reverses ports on devices attached to its own machine, and Simlock emulators are attached to the Mac.
6. **Clean up** when the test ends: stop the `ssh -R` process and the stack, and release the device with `device_close`.
