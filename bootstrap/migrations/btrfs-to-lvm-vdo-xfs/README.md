# Btrfs to LVM-VDO/XFS migration

Use this one-time migration to preserve an existing Arch VM while moving its
Btrfs root to XFS on LVM-VDO with LZ4 compression and deduplication. This is not
the normal fresh-build path.

The migration requires BIOS boot mode, a Btrfs root, and a blank 200 GiB target
volume. It creates this layout:

| LV | Size | Format |
|---|---:|---|
| `devbox/boot` | 2 GiB | ext4 on linear LVM |
| `devbox/swap` | 5 GiB | swap on linear LVM |
| `devbox/root` | 171.67 GiB logical | XFS on a 175 GiB physical VDO pool |

About 18 GiB remains free in the VG for an emergency VDO extension.

## Before running

1. Take a CloudPe snapshot of the current boot volume.
2. Attach a blank 200 GiB volume to the source VM.
3. Stop write-heavy services and jobs. Keep SSH, networking, and Tailscale up.
4. Resolve the target device with `lsblk`. Never assume it is `/dev/vdb`.

The script rejects the running root disk, non-empty targets, the wrong firmware
mode, missing tools, and targets smaller than 200 GiB. It never reboots.

## Stage the replacement volume

From the repository root, run preflight first:

```sh
sudo TARGET_DISK=/dev/vdb PREFLIGHT_ONLY=1 \
  bash bootstrap/migrations/btrfs-to-lvm-vdo-xfs/migrate.sh
```

Then run the migration:

```sh
sudo TARGET_DISK=/dev/vdb YES=1 \
  bash bootstrap/migrations/btrfs-to-lvm-vdo-xfs/migrate.sh
```

The script creates a read-only Btrfs source snapshot, copies it with rsync,
installs GRUB, builds an initramfs containing LVM and `dm-vdo`, and validates
the staged filesystems and boot artifacts. It deletes the temporary Btrfs
snapshot only after every validation passes.

The staged root receives
[`cloud-init-preserve-cloned-identity.cfg`](cloud-init-preserve-cloned-identity.cfg).
Cloud-init can configure the replacement VM's new network interface without
changing the copied hostname, SSH host keys, or generated locales. The copied
Tailscale state makes the replacement reconnect as the same tailnet device.

## Cut over on CloudPe

1. Power off the source VM and keep it stopped.
2. In the Advanced Dashboard, open the volume list and detach the staged
   non-boot volume from the source VM.
3. Create a VM with **Deploy from Volume**. Select the detached volume as its
   boot volume.
4. Use the name `devbox`, the same region, flavor, networks, and security group.
   Keep UEFI disabled because the staged disk uses BIOS boot.
5. Boot the replacement VM. Never run it at the same time as the source VM.

CloudPe documents the dashboard flow in
[How to create Virtual Machines from Advance Panel](https://www.cloudpe.com/knowledge-base/how-to-create-virtual-machines-from-advance-panel/)
and permits detaching only non-boot volumes in
[Attaching and Detaching Volumes](https://www.cloudpe.com/knowledge-base/attaching-and-detaching-volumes/).

## Validate the replacement

Use the CloudPe console if Tailscale needs a minute to reconnect.

```sh
findmnt -no SOURCE,FSTYPE /
findmnt -no SOURCE,FSTYPE /boot
sudo lvs -a -o \
  lv_name,lv_size,data_percent,vdo_compression,vdo_deduplication,vdo_saving_percent \
  devbox
systemctl --failed
tailscale status
```

Expected root and boot filesystems:

```text
/dev/mapper/devbox-root xfs
/dev/mapper/devbox-boot ext4
```

Verify the development services before changing or deleting the source VM.
Recreate any CloudPe snapshot schedules, monitoring, and external DNS that were
attached to the old VM rather than stored on disk.

## Roll back

Power off the replacement VM before restarting the source VM. They contain the
same machine ID, SSH host keys, and Tailscale state, so running both causes an
identity conflict. Keep the source VM and its snapshot until the replacement
has passed normal workload checks.
