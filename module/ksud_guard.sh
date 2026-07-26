#!/system/bin/sh
# Protect /data/adb/ksud from susfs-module binary installers.
#
# Some managers (notably ReSukiSU, and other integrated builds) ship ONE
# multi-call binary hardlinked as BOTH /data/adb/ksud and
# /data/adb/ksu/bin/ksu_susfs (same inode). A standalone susfs4ksu module then
# does `cp -f newbin /data/adb/ksu/bin/ksu_susfs` - an in-place overwrite that
# also clobbers /data/adb/ksud, so the KernelSU daemon (and `su`) break.
#
# Fix: de-duplicate ksu_susfs into its own inode, then make that copy IMMUTABLE
# (chattr +i). Immutability is what makes it hold:
#   - the manager's periodic re-link (`ln -f ksud ksu_susfs`, e.g. on app launch)
#     fails, so the split survives;
#   - the susfs module's `cp -f` over ksu_susfs fails, so ksud is never touched.
# ksud itself is left a separate, writable inode the manager can still update.
# We only ever touch ksu_susfs (the CLI), never ksud (the daemon). No-op on
# stock KSU/KSUN (standalone ksu_susfs) or when susfs isn't installed. Idempotent
# (a boot where it's already split+locked does nothing). uninstall.sh clears +i.
PATH=/data/adb/ksu/bin:$PATH
KSUD=/data/adb/ksud
SUSFS=/data/adb/ksu/bin/ksu_susfs

CHATTR()  { chattr "$@" 2>/dev/null || busybox chattr "$@" 2>/dev/null; }
is_immutable() { { lsattr "$1" 2>/dev/null || busybox lsattr "$1" 2>/dev/null; } | awk '{print $1}' | grep -q 'i'; }

lock() {   # chattr +i, return 0 if it stuck
	CHATTR +i "$SUSFS"
	is_immutable "$SUSFS"
}

[ -f "$KSUD" ] && [ -f "$SUSFS" ] || exit 0

ino_k=$(stat -c %i "$KSUD" 2>/dev/null)
ino_s=$(stat -c %i "$SUSFS" 2>/dev/null)
[ -n "$ino_k" ] || exit 0

# already fully protected (split AND locked) -> nothing to do
[ "$ino_k" != "$ino_s" ] && is_immutable "$SUSFS" && exit 0

# never act on a broken state: only proceed if ksud currently works
"$KSUD" -V 2>/dev/null | grep -qiE "ksud|uapi" || exit 0

if [ "$ino_k" != "$ino_s" ]; then
	# already de-linked, just (re)apply the lock
	lock && echo "[+] ksud_guard: ksu_susfs already split, locked immutable" \
	     || echo "[+] ksud_guard: ksu_susfs already split (chattr +i unsupported)"
	exit 0
fi

# shared inode: de-duplicate ksu_susfs into its own inode, then lock.
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
		if lock; then
			echo "[+] ksud_guard: ksu_susfs de-linked + locked immutable - ksud shielded"
		else
			echo "[+] ksud_guard: ksu_susfs de-linked (chattr +i unsupported - split only)"
		fi
	else
		echo "[!] ksud_guard: verify/replace failed, left ksu_susfs untouched"
	fi
else
	echo "[!] ksud_guard: copy failed, left ksu_susfs untouched"
fi
rm -rf "$d" 2>/dev/null

# EOF
