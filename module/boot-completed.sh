#!/system/bin/sh
# Runs once the UI is up (boot-completed stage): refresh the module-card badge
# and post a notification telling the user which su mode is active.
PATH=/data/adb/ksu/bin:$PATH
D=/data/adb/modules/kernelnosu

sh "$D/set_desc.sh"

sc=$(/data/adb/ksud feature list 2>/dev/null | awk '/su_compat \(ID=0\)/{print (/ENABLED/)?"on":"off"}')
mnt=$(grep -c " /system/bin/su " /proc/self/mountinfo 2>/dev/null)

if [ "${mnt:-0}" -ge 1 ]; then
	if [ "$sc" = "off" ]; then msg="🟢 Real su active - sucompat off, consistent & hidden from apps"
	else                      msg="🟡 Real su + sucompat both on - disable sucompat for a clean su"; fi
elif [ "$sc" = "on" ]; then   msg="🟡 sucompat mode - real su not mounted (path-hook, detectable)"
else                          msg="🔴 No su active - self-heal did not restore a fallback, check the module"; fi

# best-effort; the notification service is up by boot-completed
cmd notification post -S bigtext -t "KernelNoSU" knsu "$msg" >/dev/null 2>&1 \
	&& echo "[+] notified: $msg" \
	|| echo "[-] notification not posted (cmd notification unavailable)"

# EOF
