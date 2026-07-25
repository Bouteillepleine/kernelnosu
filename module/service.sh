#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
MODDIR=${0%/*}

SU_BINARY="$(busybox find $MODDIR -name "su")"

# NOTE: the susfs mount-hide registration lives in post-mount.sh (runs right
# after the magic mount, before zygote) - not here. At service stage apps have
# already started, so registering this late would miss early launchers.

# wait for boot-complete
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 1
done

[ -f "$SU_BINARY" ] && /data/adb/ksud feature set 0 0

# EOF
