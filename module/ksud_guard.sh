#!/system/bin/sh
# Protect /data/adb/ksud from susfs-module binary installers.
#
# Some managers (notably ReSukiSU, and other integrated builds) ship ONE
# multi-call binary hardlinked as BOTH /data/adb/ksud and
# /data/adb/ksu/bin/ksu_susfs (same inode). A standalone susfs4ksu module then
# does `cp -f newbin /data/adb/ksu/bin/ksu_susfs` - an in-place overwrite that
# also clobbers /data/adb/ksud, so the KernelSU daemon (and `su`) break on the
# next boot.
#
# We defuse this by de-duplicating ksu_susfs into its own inode: after this,
# a later in-place overwrite of ksu_susfs can never reach ksud. We only touch
# ksu_susfs (the CLI), never ksud (the daemon). No-op when ksu_susfs is already
# standalone (stock KSU / KSUN) or susfs isn't installed. Idempotent.
PATH=/data/adb/ksu/bin:$PATH
KSUD=/data/adb/ksud
SUSFS=/data/adb/ksu/bin/ksu_susfs

[ -f "$KSUD" ] && [ -f "$SUSFS" ] || exit 0

ino_k=$(stat -c %i "$KSUD" 2>/dev/null)
ino_s=$(stat -c %i "$SUSFS" 2>/dev/null)
[ -n "$ino_k" ] && [ "$ino_k" = "$ino_s" ] || exit 0        # not hardlinked -> nothing to do

# only proceed if ksud currently works, so we never act on an already-broken state
"$KSUD" -V 2>/dev/null | grep -qiE "ksud|uapi" || exit 0

# Copy into a temp dir but KEEP the basename 'ksu_susfs': multi-call binaries
# dispatch on argv[0], so the copy must be invoked as ksu_susfs to verify.
d="/data/adb/ksu/bin/.knsu_guard"
rm -rf "$d" 2>/dev/null
mkdir -p "$d" || exit 0
tmp="$d/ksu_susfs"

if cp -f "$SUSFS" "$tmp" 2>/dev/null; then
	chmod 0755 "$tmp" 2>/dev/null
	busybox chcon --reference="$SUSFS" "$tmp" 2>/dev/null
	if "$tmp" show version >/dev/null 2>&1 && mv -f "$tmp" "$SUSFS" 2>/dev/null; then
		echo "[+] ksud_guard: de-linked ksu_susfs from ksud (susfs-clobber shield)"
	else
		echo "[!] ksud_guard: verify/replace failed, left ksu_susfs untouched"
	fi
else
	echo "[!] ksud_guard: copy failed, left ksu_susfs untouched"
fi
rm -rf "$d" 2>/dev/null

# EOF
