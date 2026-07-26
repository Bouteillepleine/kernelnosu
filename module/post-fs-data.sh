#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH

# Disable sucompat BEFORE modules are mounted. ksud runs module post-fs-data
# scripts in the post-fs-data event, which is *before* the (meta)module mount
# stage. This matters: while su_compat is on, the kernel spoofs /system/bin/su
# (stat shows a fake file but open returns ENOENT), and that spoofed, non-real
# dentry prevents the magic-mount backend from landing our real su there
# (confirmed on OP15 + magic_mount_rs). Turning it off here leaves the path
# clean so the mount succeeds; the real su then serves root from that point on.
#
# This is runtime-only (it does NOT write /data/adb/ksu/.feature_config), so if
# the su mount ever fails to materialise, a plain reboot reloads the on-disk
# (enabled) config and restores sucompat as a fallback - self-healing.

# Shield /data/adb/ksud from susfs-module binary installers first (no-op unless
# vulnerable). Runs before anything else so the daemon is protected early.
MODDIR=${0%/*}
[ -f "$MODDIR/ksud_guard.sh" ] && sh "$MODDIR/ksud_guard.sh"

/data/adb/ksud feature set 0 0

# EOF
