#!/system/bin/sh
# Self-healing safety fallback.
# Confirm the real su actually landed at /system/bin/su and is byte-identical
# to our module binary. If it didn't (mount failed, wrong file, backend quirk),
# the device would otherwise be left with sucompat OFF and no working su ->
# root broken until reboot. In that case we re-enable sucompat so root can
# never break. Runs at post-mount and on demand from the WebUI.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu
SU=/system/bin/su

ok=0
if grep -q " /system/bin/su " /proc/self/mountinfo 2>/dev/null && head -c4 "$SU" >/dev/null 2>&1; then
	a=$(busybox sha1sum "$SU" 2>/dev/null | cut -d' ' -f1)
	b=$(busybox sha1sum "$D/system/bin/su" 2>/dev/null | cut -d' ' -f1)
	[ -n "$a" ] && [ "$a" = "$b" ] && ok=1
fi

if [ "$ok" = 1 ]; then
	echo "[+] verify: real su landed and consistent"
	exit 0
fi

echo "[!] verify: real su missing/mismatch -> re-enabling sucompat (safety fallback)"
/data/adb/ksud feature set 0 1
exit 1

# EOF
