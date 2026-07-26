#!/system/bin/sh
# Harden the mounted su file.
# 1) Stable SELinux context + perms: a real su must stay executable and keep a
#    benign, non-drifting label matching its target directory's own files.
# 2) Hide it from non-su-allowed apps via susfs path hiding (defense-in-depth).
# NOTE: we deliberately do NOT spoof its kstat/size. Faking stat fields would
# make stat() disagree with what read() returns - recreating the exact
# stat-vs-read inconsistency this module exists to remove.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu
T=/data/adb/ksu/bin/ksu_susfs

# SU / SRC come from customize.sh's auto-detected target (su_target/su_source),
# so this stays correct whichever partition was picked (/product, /system_ext,
# /vendor, /odm, or /system as the universal fallback).
SU=$(cat "$D/su_target" 2>/dev/null)
SRC="$D/$(cat "$D/su_source" 2>/dev/null)"
[ -n "$SU" ] || SU=/system/bin/su
[ -n "$SRC" ] && [ "$SRC" != "$D/" ] || SRC="$D/system/bin/su"

# only harden if our real su is actually in place
[ "$(stat -c %s "$SU" 2>/dev/null)" = "$(stat -c %s "$SRC" 2>/dev/null)" ] || {
	echo "[-] harden: real su not in place, skipping"
	exit 0
}

parent=$(dirname "$SU")
chmod 0755 "$SU" 2>/dev/null
busybox chcon --reference="$parent" "$SU" 2>/dev/null \
	|| chcon u:object_r:system_file:s0 "$SU" 2>/dev/null

if [ -x "$T" ]; then
	"$T" add_sus_path "$SU" >/dev/null 2>&1
	"$T" hide_sus_mnts_for_non_su_procs 1 >/dev/null 2>&1
fi

ctx=$(ls -Z "$SU" 2>/dev/null | awk '{print $1}')
echo "[+] harden: perms=0755 context=${ctx:-?} + hidden from non-su apps"

# EOF
