#!/usr/bin/env bash
# Convert a fresh machine's root to XFS on LVM-VDO with LZ4 compression and
# deduplication, matching the devbox layout. Not a migration: it copies the
# running root to a blank second volume and stages GRUB, then you cut over.
#
# Layout on the 200 GiB target disk:
#   [1 MiB BIOS boot][LVM PV]
#     devbox/boot: 2 GiB linear LV, ext4
#     devbox/swap: 5 GiB linear LV
#     devbox/root: 175 GiB physical VDO LV, XFS
#     about 18 GiB remains free in the VG for emergency VDO extension
#
# The initial VDO logical size is not overprovisioned. LVM chooses the largest
# logical size that can hold incompressible data.
#
# Run as root:
#   sudo TARGET_DISK=/dev/vdb bash scripts/to-vdo.sh
#   sudo TARGET_DISK=/dev/vdb PREFLIGHT_ONLY=1 bash scripts/to-vdo.sh
set -euo pipefail

TARGET_DISK=${TARGET_DISK:-}
PREFLIGHT_ONLY=${PREFLIGHT_ONLY:-0}
YES=${YES:-0}
VG=devbox
ROOT_LV=root
BOOT_LV=boot
SWAP_LV=swap
BOOT_SIZE=2G
SWAP_SIZE=5G
VDO_PHYSICAL_SIZE=175G
MIN_TARGET_BYTES=$((200 * 1024 * 1024 * 1024))
MOUNT_DIR=/mnt/devbox-vdo

fail() {
  echo "error: $*" >&2
  exit 1
}

[ "$(id -u)" = 0 ] || fail "run as root"
[ -n "$TARGET_DISK" ] || fail "set TARGET_DISK explicitly, for example /dev/vdb"
[ -b "$TARGET_DISK" ] || fail "$TARGET_DISK is not a block device"
[ "$(lsblk -rndo TYPE "$TARGET_DISK")" = disk ] || fail "$TARGET_DISK is not a disk"

ROOT_SOURCE=$(readlink -f "$(findmnt -n -o SOURCE /)")
ROOT_PARENT=$(lsblk -ndo PKNAME "$ROOT_SOURCE")
[ -n "$ROOT_PARENT" ] || fail "cannot resolve the physical disk containing $ROOT_SOURCE"
ROOT_DISK=/dev/$ROOT_PARENT

[ "$TARGET_DISK" != "$ROOT_DISK" ] || fail "$TARGET_DISK contains the running root filesystem"
[ ! -d /sys/firmware/efi ] || fail "this script only supports the devbox's BIOS boot mode"

TARGET_BYTES=$(blockdev --getsize64 "$TARGET_DISK")
[ "$TARGET_BYTES" -ge "$MIN_TARGET_BYTES" ] \
  || fail "$TARGET_DISK must be at least 200 GiB"

DEVICE_COUNT=$(lsblk -nrpo NAME "$TARGET_DISK" | wc -l)
[ "$DEVICE_COUNT" -eq 1 ] || fail "$TARGET_DISK already has partitions"
if wipefs -n "$TARGET_DISK" | grep -q .; then
  wipefs -n "$TARGET_DISK"
  fail "$TARGET_DISK contains filesystem or partition signatures"
fi
if lsblk -nrpo MOUNTPOINTS "$TARGET_DISK" | grep -q '[^[:space:]]'; then
  fail "$TARGET_DISK or one of its children is mounted"
fi
if vgs "$VG" >/dev/null 2>&1; then
  fail "volume group $VG already exists"
fi
if mountpoint -q "$MOUNT_DIR"; then
  fail "$MOUNT_DIR is already a mountpoint"
fi

echo ">> checking conversion tools"
REQUIRED_COMMANDS=(
  arch-chroot blkid blockdev dmsetup findmnt grub-install
  grub-mkconfig install lsblk lsinitcpio lvcreate lvs mkfs.ext4 mkfs.xfs mkinitcpio
  mkswap modprobe mount mountpoint partprobe pvcreate rsync sfdisk
  sync udevadm umount vgchange vgcreate vgs wipefs xfs_info
)
for command_name in "${REQUIRED_COMMANDS[@]}"; do
  command -v "$command_name" >/dev/null || fail "missing command: $command_name"
done

modprobe dm-vdo
dmsetup targets | awk '$1 == "vdo" { found = 1 } END { exit !found }' \
  || fail "the kernel did not register the VDO device-mapper target"

echo ">> source: $ROOT_SOURCE on $ROOT_DISK"
echo ">> target: $TARGET_DISK ($(lsblk -ndro SIZE "$TARGET_DISK"))"
echo ">> layout: 2 GiB boot, 5 GiB swap, 175 GiB physical VDO, about 18 GiB VG reserve"
echo ">> VDO compression and deduplication will be enabled explicitly"

if [ "$PREFLIGHT_ONLY" = 1 ]; then
  echo ">> preflight passed; no disk changes were made"
  exit 0
fi

echo ">> THIS WILL PARTITION AND OVERWRITE $TARGET_DISK"
echo ">> Stop agents and write-heavy jobs before continuing."
echo ">> Press enter to continue, or Ctrl-C to abort. Set YES=1 to skip this prompt."
[ "$YES" = 1 ] || read -r

if [[ "$TARGET_DISK" =~ (nvme|mmcblk) ]]; then
  TARGET_PART=${TARGET_DISK}p2
else
  TARGET_PART=${TARGET_DISK}2
fi

cleanup_resources() (
  set +e
  for path in run sys proc dev; do
    if mountpoint -q "$MOUNT_DIR/$path"; then
      umount -R "$MOUNT_DIR/$path"
    fi
  done
  if mountpoint -q "$MOUNT_DIR/boot"; then
    umount "$MOUNT_DIR/boot"
  fi
  if mountpoint -q "$MOUNT_DIR"; then
    umount "$MOUNT_DIR"
  fi
  if vgs "$VG" >/dev/null 2>&1; then
    vgchange -an "$VG" >/dev/null 2>&1
  fi
)
trap cleanup_resources EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo ">> partitioning $TARGET_DISK"
sfdisk --wipe always --wipe-partitions always "$TARGET_DISK" <<'EOF'
label: gpt
start=2048, size=2048, type=21686148-6449-6E6F-744E-656564454649, name=BIOSBOOT
start=4096, type=E6D6D379-F507-44C2-A23C-238F2A3DF928, name=LVM
EOF
partprobe "$TARGET_DISK"
udevadm settle
[ -b "$TARGET_PART" ] || fail "partition device $TARGET_PART did not appear"

echo ">> creating LVM, VDO, filesystems, and swap"
pvcreate -y "$TARGET_PART"
vgcreate "$VG" "$TARGET_PART"
lvcreate -y -n "$BOOT_LV" -L "$BOOT_SIZE" "$VG"
mkfs.ext4 -L boot "/dev/mapper/$VG-$BOOT_LV"
lvcreate -y -n "$SWAP_LV" -L "$SWAP_SIZE" "$VG"
mkswap "/dev/mapper/$VG-$SWAP_LV"
lvcreate -y --type vdo -n "$ROOT_LV" -L "$VDO_PHYSICAL_SIZE" \
  --compression y --deduplication y "$VG"
mkfs.xfs -K -L root "/dev/mapper/$VG-$ROOT_LV"

mkdir -p "$MOUNT_DIR"
mount "/dev/mapper/$VG-$ROOT_LV" "$MOUNT_DIR"
mkdir -p "$MOUNT_DIR/boot"
mount "/dev/mapper/$VG-$BOOT_LV" "$MOUNT_DIR/boot"

echo ">> copying the running root"
rsync -aHAXS --numeric-ids --info=progress2 \
  --exclude='/dev/***' --exclude='/proc/***' --exclude='/sys/***' \
  --exclude='/run/***' --exclude='/tmp/***' --exclude='/mnt/***' \
  --exclude='/efi/***' --exclude='/lost+found/***' \
  / "$MOUNT_DIR/"

install -Dm644 /dev/stdin "$MOUNT_DIR/etc/cloud/cloud.cfg.d/99-preserve-cloned-identity.cfg" <<'EOF'
#cloud-config
preserve_hostname: true
ssh_deletekeys: false
EOF

NEW_UUID=$(blkid -s UUID -o value "/dev/mapper/$VG-$ROOT_LV")
[ -n "$NEW_UUID" ] || fail "could not read the new XFS UUID"
BOOT_UUID=$(blkid -s UUID -o value "/dev/mapper/$VG-$BOOT_LV")
[ -n "$BOOT_UUID" ] || fail "could not read the boot filesystem UUID"
cat > "$MOUNT_DIR/etc/fstab" <<EOF
UUID=$NEW_UUID / xfs defaults 0 0
UUID=$BOOT_UUID /boot ext4 defaults 0 2
/dev/mapper/$VG-$SWAP_LV none swap defaults 0 0
EOF

echo ">> preparing the new root for boot"
if ! grep -Eq '^HOOKS=.*[[:space:](]lvm2[[:space:])]' "$MOUNT_DIR/etc/mkinitcpio.conf"; then
  sed -i -E 's/(^HOOKS=.*[[:space:]])block([[:space:]])/\1block lvm2\2/' \
    "$MOUNT_DIR/etc/mkinitcpio.conf"
fi
grep -Eq '^HOOKS=.*[[:space:](]lvm2[[:space:])]' "$MOUNT_DIR/etc/mkinitcpio.conf" \
  || fail "failed to add the lvm2 initramfs hook"

if ! grep -Eq '^MODULES=.*dm[-_]vdo' "$MOUNT_DIR/etc/mkinitcpio.conf"; then
  sed -i -E 's/^MODULES=\(/MODULES=(dm-vdo /' "$MOUNT_DIR/etc/mkinitcpio.conf"
fi
grep -Eq '^MODULES=.*dm[-_]vdo' "$MOUNT_DIR/etc/mkinitcpio.conf" \
  || fail "failed to add dm-vdo to the initramfs modules"

mount --rbind /dev "$MOUNT_DIR/dev"
mount --make-rslave "$MOUNT_DIR/dev"
mount -t proc proc "$MOUNT_DIR/proc"
mount --rbind /sys "$MOUNT_DIR/sys"
mount --make-rslave "$MOUNT_DIR/sys"
mount --rbind /run "$MOUNT_DIR/run"
mount --make-rslave "$MOUNT_DIR/run"

arch-chroot "$MOUNT_DIR" /bin/bash -eux <<CHROOT
mkinitcpio -P
grub-install --recheck --target=i386-pc "$TARGET_DISK"
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable fstrim.timer
CHROOT

echo ">> validating the staged system"
grep -Eq "^[[:space:]]*linux[[:space:]].*root=/dev/mapper/$VG-$ROOT_LV([[:space:]]|$)" \
  "$MOUNT_DIR/boot/grub/grub.cfg" \
  || fail "GRUB configuration does not reference the VDO root LV"
arch-chroot "$MOUNT_DIR" lsinitcpio /boot/initramfs-linux.img \
  | grep -Eq 'dm[-_]vdo' \
  || fail "the initramfs does not contain dm-vdo"
xfs_info "$MOUNT_DIR"
lvs -a -o lv_name,lv_size,data_percent,vdo_compression,vdo_deduplication,vdo_saving_percent "$VG"

cleanup_resources
trap - EXIT INT TERM

cat <<EOF

>> Conversion staged. Nothing has booted from $TARGET_DISK yet.
>>
>> CloudPe cutover:
>>   1. power off this VM and keep it stopped
>>   2. detach $TARGET_DISK, the new non-boot volume
>>   3. deploy a new VM from that volume with the same flavor and security group
>>   4. boot and verify: findmnt -no SOURCE,FSTYPE /
>>   5. verify VDO: sudo lvs -a -o lv_name,lv_size,data_percent,vdo_compression,vdo_deduplication,vdo_saving_percent $VG
>>
>> Rollback: power off the new VM before restarting this one from $ROOT_DISK.
>> Never run both VMs at the same time because they share machine and Tailscale identities.
EOF
