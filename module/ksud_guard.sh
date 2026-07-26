#!/system/bin/sh
# Best-effort protection for /data/adb/ksud against susfs-module installers.
#
# Some managers (notably ReSukiSU, and other integrated builds) ship ONE
# multi-call binary hardlinked as BOTH /data/adb/ksud and
# /data/adb/ksu/bin/ksu_susfs (same inode). A standalone susfs4ksu module then
# does `cp -f newbin /data/adb/ksu/bin/ksu_susfs` - an in-place overwrite that
# also clobbers /data/adb/ksud, so the KernelSU daemon (and `su`) break.
#
# Mitigation: de-duplicate ksu_susfs into its OWN inode, so a `cp -f` over it no
# longer touches ksud. Runs every boot and re-splits if the manager has since
# re-linked them.
#
# NOTE - this is BEST-EFFORT and deliberately does NOT chattr +i the copy.
# An immutable ksu_susfs blocks ksud's own asset extraction during ANY module
# flash (Oxygen Customizer onboarding, `ksud module install`, ...) failing with
# "Failed to extract assets / File exists (os error 17)". So we accept that the
# manager's periodic re-link (`ln -f ksud ksu_susfs`, e.g. on app launch) can
# re-merge the inodes between boots; the next boot re-splits them. Trade-off:
# module flashes just work, at the cost of a narrow window where a susfs update
# landing while the two are re-linked could still clobber ksud (recoverable by
# reinstalling the manager APK). No-op on stock KSU/KSUN (standalone ksu_susfs)
# or when susfs isn't installed. Idempotent.
PATH=/data/adb/ksu/bin:$PATH
KSUD=/data/adb/ksud
SUSFS=/data/adb/ksu/bin/ksu_susfs

CHATTR() { chattr "$@" 2>/dev/null || busybox chattr "$@" 2>/dev/null; }

[ -f "$KSUD" ] && [ -f "$SUSFS" ] || exit 0

# Clear any legacy immutable flag a previous (locking) version of this guard,
# or an older install, may have left on ksu_susfs - otherwise module flashes
# would keep failing even after this loosened guard ships.
CHATTR -i "$SUSFS"

ino_k=$(stat -c %i "$KSUD" 2>/dev/null)
ino_s=$(stat -c %i "$SUSFS" 2>/dev/null)
[ -n "$ino_k" ] || exit 0

# already split -> nothing to do
[ "$ino_k" != "$ino_s" ] && exit 0

# never act on a broken state: only proceed if ksud currently works
"$KSUD" -V 2>/dev/null | grep -qiE "ksud|uapi" || exit 0

# shared inode: de-duplicate ksu_susfs into its own inode.
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
		echo "[+] ksud_guard: ksu_susfs de-linked (best-effort, not locked)"
	else
		echo "[!] ksud_guard: verify/replace failed, left ksu_susfs untouched"
	fi
else
	echo "[!] ksud_guard: copy failed, left ksu_susfs untouched"
fi
rm -rf "$d" 2>/dev/null

# EOF
