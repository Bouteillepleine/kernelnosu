#!/system/bin/sh
# Self-healing safety fallback.
# Confirm the real su actually landed at its auto-detected target and is
# byte-identical to our module binary. If it didn't - observed to be a boot-time
# race on some devices - retry once by re-invoking the active metamodule's own
# mount script before giving up. If it STILL didn't land, the device would
# otherwise be left with sucompat OFF and no working su -> root broken until
# reboot, so re-enable sucompat as the last-resort fallback. Runs at the
# service stage and on demand from the WebUI.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu

SU=$(cat "$D/su_target" 2>/dev/null)
SRC="$D/$(cat "$D/su_source" 2>/dev/null)"
[ -n "$SU" ] || SU=/system/bin/su
[ -n "$SRC" ] && [ "$SRC" != "$D/" ] || SRC="$D/system/bin/su"

check_ok() {
	head -c4 "$SU" >/dev/null 2>&1 || return 1
	a=$(busybox sha1sum "$SU" 2>/dev/null | cut -d' ' -f1)
	b=$(busybox sha1sum "$SRC" 2>/dev/null | cut -d' ' -f1)
	[ -n "$a" ] && [ "$a" = "$b" ]
}

if check_ok; then
	echo "[+] verify: real su landed and consistent"
	exit 0
fi

echo "[!] verify: real su missing/mismatch -> retrying mount"
meta=$(readlink /data/adb/metamodule 2>/dev/null)
if [ -n "$meta" ] && [ -f "$meta/metamount.sh" ]; then
	sh "$meta/metamount.sh" >/dev/null 2>&1
fi

if check_ok; then
	echo "[+] verify: retry succeeded, real su landed and consistent"
	exit 0
fi

echo "[!] verify: retry failed -> re-enabling sucompat (safety fallback)"
/data/adb/ksud feature set 0 1
exit 1

# EOF
