#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
MODDIR=${0%/*}

# post-mount runs AFTER KSU magic-mounts modules but BEFORE zygote, so
# /system/bin/su already exists here (post-fs-data would be too early - the
# mount isn't up yet and ksu_susfs realpath() would fail).

SU_BINARY="$(busybox find $MODDIR -name "su")"

# on-device mounted path = module-internal path minus the $MODDIR prefix
# e.g. /data/adb/modules/kernelnosu/system/bin/su -> /system/bin/su
SU_MOUNTED="/${SU_BINARY#$MODDIR/}"

# Hide the injected su bind-mount from non-su-allowed UIDs. add_try_umount
# realpath()s the target, which resolves now that the mount is up. KSU also
# umounts module mounts for these UIDs; susfs umount takes precedence and this
# covers configs where the auto-umount doesn't fire. Narrowly scoped to our
# file only - we never touch global susfs toggles. No-op without susfs.
KSU_SUSFS=/data/adb/ksu/bin/ksu_susfs
if [ -x "$KSU_SUSFS" ] && [ -n "$SU_BINARY" ]; then
	"$KSU_SUSFS" add_try_umount "$SU_MOUNTED" 1 > /dev/null 2>&1 \
		&& echo "[+] susfs: $SU_MOUNTED registered for non-root umount"
fi

# EOF
