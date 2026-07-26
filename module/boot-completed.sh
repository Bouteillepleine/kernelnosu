#!/system/bin/sh
# Runs once the UI is up (boot-completed stage): re-verify the real su mount,
# refresh the module-card badge and post a notification about the su mode.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu

# Late self-heal. The metamodule mounts /product/bin/su very early, but the ROM
# keeps setting up /product afterwards (its own overlay submounts land later),
# and that can tear the early submount back down - leaving real su missing and
# the service-stage retry too early to stick. boot-completed runs once /product
# is fully settled, so verify.sh's re-invoke of the metamodule mount lands
# reliably here (proven: a late re-invoke restores /product/bin/su globally,
# for init and every namespace). If it still can't, verify.sh falls back to
# sucompat so root is never left broken.
sh "$D/verify.sh"
sh "$D/harden.sh"
sh "$D/set_desc.sh"

SU=$(cat "$D/su_target" 2>/dev/null)
SRC="$D/$(cat "$D/su_source" 2>/dev/null)"
[ -n "$SU" ] || SU=/system/bin/su
[ -n "$SRC" ] && [ "$SRC" != "$D/" ] || SRC="$D/system/bin/su"

sc=$(/data/adb/ksud feature list 2>/dev/null | awk '/su_compat \(ID=0\)/{print (/ENABLED/)?"on":"off"}')
real=0
[ "$(stat -c %s "$SU" 2>/dev/null)" = "$(stat -c %s "$SRC" 2>/dev/null)" ] && real=1

if [ "$real" = 1 ]; then
	if [ "$sc" = "off" ]; then msg="🟢 Real su active - $SU, sucompat off, consistent";
	else                       msg="🟡 Real su + sucompat both on - disable sucompat for a clean su"; fi
elif [ "$sc" = "on" ]; then    msg="🟡 sucompat mode - real su not mounted (path-hook, detectable)";
else                           msg="🔴 No su active - self-heal did not restore a fallback, check the module"; fi

# best-effort; the notification service is up by boot-completed
cmd notification post -S bigtext -t "KernelNoSU" knsu "$msg" >/dev/null 2>&1 \
	&& echo "[+] notified: $msg" \
	|| echo "[-] notification not posted (cmd notification unavailable)"

# EOF
