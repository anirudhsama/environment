#!/usr/bin/env bash
# Arch devbox bootstrap — root-only, once, on first boot (via the minimal
# user-data's runcmd) or manually: sudo bash bootstrap.sh
#
# Scope: turn a raw Arch cloud image into a machine that can fetch and run
# `mise bootstrap`. Nothing more. Everything that describes *my environment* —
# packages, dotfiles, services, tools, helper scripts — lives in the repo's
# mise.toml. If you're tempted to add something here, add it there instead.
#
# What's left is only what needs root AND has to happen before the repo exists:
# filesystem (swap), system locale, sshd hardening, pacman trust/mirrors, and
# a two-package seed.
#
# After it finishes:
#   1. sudo tailscale up --ssh --operator=ani   -> open the URL on your Mac
#   2. Tailscale admin console: Machines -> devbox -> Disable key expiry
#   3. From your Mac, verify:  ssh ani@devbox   (over the tailnet)
#   4. git clone <repo> ~/dev/environment && cd it && mise trust . && mise bootstrap
#   5. lockdown          -> closes the public interface (ships with the repo)
set -euo pipefail

# Irreducible: git fetches the repo. mise comes from its own installer below,
# and applies everything else. Do not grow this list.
SEED_PKGS=(git)

echo ">> swap (coding agents eat RAM; keeps a small VPS alive)"
# Root fs is btrfs: plain fallocate files can't be swap there (CoW).
# The cloudimg already ships a 512M /swap/swapfile; we add 4G alongside.
if [ ! -f /swap/swapfile-4g ]; then
  if [ "$(findmnt -n -o FSTYPE /)" = "btrfs" ]; then
    btrfs filesystem mkswapfile --size 4g /swap/swapfile-4g
  else
    dd if=/dev/zero of=/swap/swapfile-4g bs=1M count=4096 status=none
    chmod 600 /swap/swapfile-4g
    mkswap /swap/swapfile-4g
  fi
  swapon /swap/swapfile-4g
  echo '/swap/swapfile-4g none swap defaults 0 0' >> /etc/fstab
fi

echo ">> locales (cloudimg ships none; mosh-server refuses to start without UTF-8)"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^en_IN UTF-8' /etc/locale.gen || echo 'en_IN UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo ">> sshd hardening: key-only, no root"
# Stays here, not in mise bootstrap: this should be in force before the box is
# reachable, not several minutes later.
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
EOF

echo ">> pacman: trust, India mirrors, full sync, seed packages"
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm --needed reflector
reflector --country India,Singapore --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || true
pacman -Su --noconfirm
pacman -S --noconfirm --needed "${SEED_PKGS[@]}"

systemctl restart sshd

echo ">> mise (vendor installer, not a package)"
# Deliberately NOT pacman: mise ships near-daily and every distro lags it — the
# one package where that's true. The vendor installer is also the only route
# that enables `mise self-update`, which the `update` helper relies on.
# Installs to ~/.local/bin/mise, so it must run as ani, not root.
sudo -u ani bash -c 'curl -fsSL https://mise.run | sh'

echo ">> DONE. Next steps:"
echo ">>   1. git clone https://github.com/<you>/environment ~/dev/environment"
# Absolute path: Arch's /etc/profile doesn't put ~/.local/bin on PATH, and
# mise's own shell activation isn't written until `mise bootstrap` runs.
echo ">>      cd ~/dev/environment && ~/.local/bin/mise trust . && ~/.local/bin/mise bootstrap"
echo ">>   2. sudo tailscale up --ssh --operator=ani  (auth in browser; disable key expiry in admin console)"
echo ">>   3. verify tailnet ssh from another device"
echo ">>   4. lockdown   (closes the public interface)"
