#!/system/bin/sh
PATH=/data/adb/ksu/bin:$PATH

# Late-load (LKM) counterpart of post-fs-data.sh.
# When KernelSU is loaded late (as an LKM by a process other than init, pid != 1),
# ksud takes the late-load path: late-load -> mount -> post-mount -> ... and it
# does NOT run the post-fs-data stage. The `late-load` stage, however, runs just
# BEFORE the (meta)module mount - the same slot we need to disable sucompat so
# its /system/bin/su spoof doesn't block the real su from being mounted there.
# Normal boots run post-fs-data.sh instead (this stage only fires on late load),
# so the two never double-fire. Runtime-only -> a reboot self-heals.
#
# Note: pure LKM means a stock, unpatched kernel = no SUSFS, so the susfs-based
# hardening in post-mount is a no-op there; KSU's own per-app umount still hides
# the su, and the core "real su, no sucompat tell" benefit still applies.

# Shield /data/adb/ksud from susfs-module binary installers (no-op unless
# ksu_susfs is hardlinked to ksud, e.g. some integrated builds).
MODDIR=${0%/*}
[ -f "$MODDIR/ksud_guard.sh" ] && sh "$MODDIR/ksud_guard.sh"

/data/adb/ksud feature set 0 0

# EOF
