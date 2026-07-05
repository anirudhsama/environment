# Devbox rebuild runbook (CloudPe, Arch)

## 0. Image (once per Arch release, already uploaded)

`https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2`
— official cloud image, cloud-init + virtio baked in. Upload via
Virtual Machines → Images → Add Image (OS: Generic Linux, UEFI off).
Verify: `shasum -a 256` against the `.SHA256` file next to the download.

## 1. Security group (assign at VM creation — NOT the default group)

| Direction | Rule | Why |
|---|---|---|
| Inbound | UDP 41641 from 0.0.0.0/0 and ::/0 | Tailscale direct connections |
| Inbound | TCP 22 from 0.0.0.0/0 and ::/0 | break-glass SSH (key-only, ufw rate-limited) |
| Outbound | allow all | |

## 2. Create VM

Standard NVMe (not Eco — no upgrade path), ~80 GB. Paste `user-data-min.yaml`
into the user-data field (999-char limit — that's why it's minimal), with the
`BOOTSTRAP_URL` runcmd line either pointing at a gist of `bootstrap.sh` or
removed (then run bootstrap manually, next step).

## 3. Bootstrap

```sh
ssh ani@<public-ip>            # key from user-data
# if not run via cloud-init (copy the whole dir — bootstrap.sh reads packages/):
scp -r bootstrap ani@<ip>: && ssh ani@<ip> sudo bash bootstrap/bootstrap.sh
```

Package lists live in `packages/pacman` and `packages/aur` (one per line,
`#` comments) — edit those to add/remove software, not the script.

Then:
1. `sudo tailscale up --ssh --operator=ani` → auth URL in browser
2. Tailscale admin console → Machines → devbox → **Disable key expiry**
3. Verify from Mac: `ssh ani@devbox`
4. `sudo lockdown`
5. Set up a CloudPe snapshot schedule (the real safety net on Arch)

## 4. Dotfiles + logins

```sh
gh auth login
git clone https://github.com/<you>/environment ~/dev/environment
# first run only: bootstrap stubbed fish/mise configs; remove so stow can link
rm -f ~/.config/fish/config.fish ~/.config/mise/config.toml
~/dev/environment/install
claude ; codex ; doppler login ; atuin login
fish -c 'source ~/dev/environment/scripts/tide-settings.fish'   # prompt config (tide lives in universal vars)
printf '' > ~/.config/fish/local.fish        # host-local fish (secrets)
printf '[commit]\n\tgpgsign = false\n' > ~/.gitconfig.local
```

## Known one-time fixes already baked into bootstrap.sh

- **Locales**: cloudimg ships none; mosh-server refuses to start without UTF-8.
- **Swap on btrfs**: `fallocate` swapfiles are invalid on CoW; uses
  `btrfs filesystem mkswapfile`.
- **paru from source**: `paru-bin` links a fixed libalpm soname and breaks on
  newer pacman. If paru breaks after a pacman major bump: rebuild from AUR git.
- **Kernel upgrade before ufw**: if `lockdown` fails with "missing kernel
  module", reboot first (modules on disk belong to the new kernel).
