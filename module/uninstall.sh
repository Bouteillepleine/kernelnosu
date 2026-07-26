#!/system/bin/sh
# On removal, unlock ksu_susfs (ksud_guard may have made it immutable) so the
# manager / susfs module can manage it again.
SUSFS=/data/adb/ksu/bin/ksu_susfs
[ -f "$SUSFS" ] && { chattr -i "$SUSFS" 2>/dev/null || busybox chattr -i "$SUSFS" 2>/dev/null; }

# EOF
