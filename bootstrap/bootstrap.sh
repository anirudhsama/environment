#!/usr/bin/env bash
# Arch devbox bootstrap — everything that no longer fits in CloudPe's
# 999-char user-data field. Runs as root, once, on first boot (via the
# minimal user-data's runcmd) or manually: sudo bash bootstrap.sh
#
# After it finishes:
#   1. sudo tailscale up --ssh --operator=ani   -> open the URL on your Mac
#   2. Tailscale admin console: Machines -> devbox -> Disable key expiry
#   3. From your Mac, verify:  ssh ani@devbox   (over the tailnet)
#   4. sudo lockdown                            -> closes the public interface
#
# Ongoing: run `update` (paru -Syu wrapper) weekly, at the keyboard.
set -euo pipefail

# Package lists live in packages/{pacman,aur} — edit those, not this script.
# Keep the whole bootstrap/ dir together (scp -r bootstrap/ ...).
PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/packages"
if [ ! -f "$PKG_DIR/pacman" ] || [ ! -f "$PKG_DIR/aur" ]; then
  echo "ERROR: $PKG_DIR/{pacman,aur} not found — copy the full bootstrap/ directory." >&2
  exit 1
fi
read_pkgs() { sed 's/#.*//' "$1" | tr -s ' \t\n' '\n' | grep -v '^$'; }
mapfile -t PACMAN_PKGS < <(read_pkgs "$PKG_DIR/pacman")
mapfile -t AUR_PKGS < <(read_pkgs "$PKG_DIR/aur")

echo ">> swap (coding agents eat RAM; keeps a small VPS alive)"
# Root fs is btrfs: plain fallocate files can't be swap there (CoW).
# The cloudimg already ships a 512M /swap/swapfile; we add 4G alongside.
rm -f /swap.img
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
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
EOF

echo ">> lockdown script (run manually after verifying Tailscale SSH)"
cat > /usr/local/bin/lockdown <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if ! tailscale ip -4 >/dev/null 2>&1; then
  echo "Tailscale is not connected — refusing to enable the firewall." >&2
  exit 1
fi
ufw default deny incoming
ufw default allow outgoing
ufw allow in on tailscale0
ufw allow 41641/udp comment 'tailscale direct connections'
# Break-glass: public SSH stays key-only and rate-limited.
# Remove once you trust the provider console:  ufw delete limit 22/tcp
ufw limit 22/tcp comment 'break-glass SSH, key-only'
ufw --force enable
systemctl enable ufw
ufw status verbose
EOF
chmod 755 /usr/local/bin/lockdown

echo ">> update helper (the one manual chore Arch demands)"
cat > /usr/local/bin/update <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo ">> Consider a CloudPe snapshot before kernel/major updates."
# Keyring first avoids "signature is unknown trust" after idle weeks.
sudo pacman -Sy --noconfirm archlinux-keyring
paru -Syu
EOF
chmod 755 /usr/local/bin/update

echo ">> pacman: India mirrors, full sync, official-repo packages"
pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm --needed reflector
reflector --country India,Singapore --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || true
pacman -Su --noconfirm
echo ">> installing ${#PACMAN_PKGS[@]} packages from packages/pacman"
pacman -S --noconfirm --needed "${PACMAN_PKGS[@]}"

echo ">> monitoring: 28-day process, CPU, and memory history"
# atop records process-level samples every 10 minutes. sysstat.service enables
# its 10-minute collector plus daily rotation and summary timers.
sed -i -E 's/^HISTORY=.*/HISTORY=28/' /etc/conf.d/sysstat
systemctl enable --now atop.service sysstat.service

systemctl enable --now tailscaled
systemctl restart sshd

echo ">> paru (AUR helper): must be built as a normal user, not root"
# Built from source, not paru-bin: the prebuilt binary links a specific
# libalpm soname and breaks whenever pacman is newer (seen: .15 vs .16).
sudo -u ani bash -c 'cd && rm -rf paru && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm && cd && rm -rf paru'

echo ">> installing ${#AUR_PKGS[@]} packages from packages/aur"
sudo -u ani paru -S --noconfirm --needed "${AUR_PKGS[@]}"

echo ">> fish as ani's login shell, with mise activation"
chsh -s /usr/bin/fish ani
# Stub configs only until the dotfiles repo is stowed (symlink = repo owns it)
sudo -u ani bash -c '[ -L $HOME/.config/fish/config.fish ] || { mkdir -p $HOME/.config/fish && touch $HOME/.config/fish/config.fish && grep -q "mise activate fish" $HOME/.config/fish/config.fish || echo "mise activate fish | source" >> $HOME/.config/fish/config.fish; }'

echo ">> mise for per-project runtime pinning (node via mise; bun system-wide)"
# bash fallback kept for non-interactive bash contexts
sudo -u ani bash -c 'grep -q "mise activate" $HOME/.bashrc || echo "eval \"\$(mise activate bash)\"" >> $HOME/.bashrc'
sudo -u ani bash -c '[ -e $HOME/.config/mise/config.toml ] || mise use -g node@lts'

echo ">> herdr (native installer, not AUR: 'herdr update --handoff' upgrades the"
echo ">> server without killing running agent sessions; package installs cannot)"
sudo -u ani bash -c 'curl -fsSL https://herdr.dev/install.sh | sh'
sudo -u ani bash -c 'herdr integration install claude && herdr integration install codex' || true

echo ">> bun global CLIs (not on AUR; ~/.bun/bin is node-version-independent)"
sudo -u ani bash -c 'bun install -g hunkdiff'

echo ">> DONE. Next steps:"
echo ">>   1. sudo tailscale up --ssh --operator=ani  (auth in browser; disable key expiry in admin console)"
echo ">>   2. verify tailnet ssh from another device, then: sudo lockdown"
echo ">>   3. gh auth login"
echo ">>   4. git clone https://github.com/<you>/environment ~/dev/environment && ~/dev/environment/install"
echo ">>      (first run: see bootstrap/README.md about pre-existing config conflicts)"
