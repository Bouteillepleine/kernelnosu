#!/system/bin/sh
# Runs once the UI is up (boot-completed stage): refresh the module-card badge
# and post a notification telling the user which su mode is active.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu

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
