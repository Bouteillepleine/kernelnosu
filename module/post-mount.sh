#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
MODDIR=${0%/*}

# post-mount runs AFTER modules are mounted but BEFORE zygote, so /system/bin/su
# already exists here (post-fs-data would be too early for a path-based call).
# Order matters:
#   1) harden  - stable SELinux context/perms on the su + hide it from non-su apps
#   2) verify  - if the real su did NOT land, re-enable sucompat (self-heal so
#                root can never break); must run after harden, before we rely on it
#   3) set_desc- reflect the live su mode ([su]/[Compat]/[nosu]) on the module card
[ -f "$MODDIR/harden.sh" ]   && sh "$MODDIR/harden.sh"
[ -f "$MODDIR/verify.sh" ]   && sh "$MODDIR/verify.sh"
[ -f "$MODDIR/set_desc.sh" ] && sh "$MODDIR/set_desc.sh"

# EOF
