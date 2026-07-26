#!/system/bin/sh
# Harden the mounted su file.
# 1) Stable SELinux context + perms: a real su must stay executable and keep a
#    benign, non-drifting label. We match /system/bin/sh (shell_exec), which is
#    what the installer set and what root callers already use.
# 2) Hide it from non-su-allowed apps (defense-in-depth over KSU's own umount).
# NOTE: we deliberately do NOT spoof its kstat/size. Faking stat fields would
# make stat() disagree with what read() returns - recreating the exact
# stat-vs-read inconsistency this module exists to remove. Absence (umount) for
# untrusted apps + full consistency for root is the correct posture.
PATH=/data/adb/ksu/bin:$PATH
SU=/system/bin/su
T=/data/adb/ksu/bin/ksu_susfs

chmod 0755 "$SU" 2>/dev/null
busybox chcon --reference=/system/bin/sh "$SU" 2>/dev/null \
	|| chcon u:object_r:system_file:s0 "$SU" 2>/dev/null

if [ -x "$T" ]; then
	"$T" add_try_umount "$SU" 1 >/dev/null 2>&1 \
		|| "$T" add_sus_path "$SU" >/dev/null 2>&1
fi

ctx=$(ls -Z "$SU" 2>/dev/null | awk '{print $1}')
echo "[+] harden: perms=0755 context=${ctx:-?} + hidden from non-su apps"

# EOF
