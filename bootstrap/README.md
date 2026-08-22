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

Set up a CloudPe snapshot schedule while you're here; on Arch it's the real
safety net.

## 3. Bootstrap

```sh
ssh ani@<public-ip>            # key from user-data
scp bootstrap/bootstrap.sh ani@<ip>: && ssh ani@<ip> sudo bash bootstrap.sh
```

`bootstrap.sh` is self-contained and deliberately narrow: only what needs root
*and* has to happen before the repo exists — swap, locales, sshd hardening,
pacman trust/mirrors, `git`, and mise from `mise.run`. Everything else,
tailscale and the helper scripts included, comes from `mise.toml`.
**Add software to `mise.toml`, not to this script.**

## 4. Dotfiles + logins

```sh
# Public repo, so no auth needed — gh isn't installed yet. Absolute mise path
# because Arch's /etc/profile doesn't add ~/.local/bin to PATH; after this run
# writes mise's activation block, plain `mise` works.
git clone https://github.com/<you>/environment ~/dev/environment
cd ~/dev/environment && ~/.local/bin/mise trust . && ~/.local/bin/mise bootstrap

sudo tailscale up --ssh --operator=ani   # browser auth; then disable key expiry
                                         # in the admin console and verify
                                         # `ssh ani@devbox` from the Mac
lockdown                                 # close the public interface
```

Then log into the CLIs (`gh`, `claude`, `codex`, `grok`, `doppler`, `atuin`) —
`mise bootstrap` installed them all.

Both steps above come *after* `mise bootstrap` because tailscale and `lockdown`
now arrive with it. Until lockdown runs the perimeter is the security group —
key-only SSH on 22 — which is what protected the box during bootstrap.sh anyway.

`tailscale up` stays manual: it blocks on a browser auth URL, so it can't live
in an idempotent task. `taildrop-inbox.service` retries every 10s until it's up.

## Existing-machine storage migrations

The fresh-build flow above creates new machine, SSH, and Tailscale identities.
Do not use a state-preserving disk migration for an ordinary rebuild.

To preserve an existing Btrfs machine while moving it to XFS on LVM-VDO, use
the [Btrfs to LVM-VDO/XFS migration](migrations/btrfs-to-lvm-vdo-xfs/README.md).
It copies the running machine to a blank second volume and boots a replacement
VM from that volume. The old VM stays powered off as the rollback path.

## One-time fixes already baked into bootstrap.sh

- **Locales**: cloudimg ships none; mosh-server won't start without UTF-8.
- **Swap on btrfs**: `fallocate` swapfiles are invalid on CoW; uses
  `btrfs filesystem mkswapfile`.
- **Kernel upgrade before ufw**: if `lockdown` fails with "missing kernel
  module", reboot first — the modules on disk belong to the new kernel.
