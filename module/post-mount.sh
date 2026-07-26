#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
MODDIR=${0%/*}

# post-mount runs AFTER modules are mounted but BEFORE zygote, so /system/bin/su
# already exists here (post-fs-data would be too early for a path-based call).
#
# Belt-and-suspenders hardening only. In practice KSU already umounts this
# module's mount from non-su-allowed UIDs' namespaces, so a normal app sees
# /system/bin/su as ENOENT while root sees the real binary (verified on
# OP15/ReSukiSU). This is the fallback for kernels/configs where that
# auto-umount doesn't fire. The susfs CLI differs by build: the C susfs4ksu tool
# exposes `add_try_umount <path> <mode>`, ReSukiSU's Rust ksu_susfs exposes
# `add_sus_path <path>` (hides it from non-su "umounted" app processes). Try
# whichever exists; both are scoped to our file and no-op without susfs.

SU_BINARY="$(busybox find $MODDIR -name "su")"

# on-device mounted path = module-internal path minus the $MODDIR prefix
# e.g. /data/adb/modules/kernelnosu/system/bin/su -> /system/bin/su
SU_MOUNTED="/${SU_BINARY#$MODDIR/}"

KSU_SUSFS=/data/adb/ksu/bin/ksu_susfs
if [ -x "$KSU_SUSFS" ] && [ -n "$SU_BINARY" ]; then
	if "$KSU_SUSFS" add_try_umount "$SU_MOUNTED" 1 > /dev/null 2>&1; then
		echo "[+] susfs: $SU_MOUNTED add_try_umount"
	elif "$KSU_SUSFS" add_sus_path "$SU_MOUNTED" > /dev/null 2>&1; then
		echo "[+] susfs: $SU_MOUNTED add_sus_path"
	fi
fi

# EOF
