#!/system/bin/sh
# Refresh the module card description in the manager to reflect the live su mode:
#   [su]      - real su mounted, sucompat off (the goal state)
#   [su+Compat] - real su mounted but sucompat also on (fall back still armed)
#   [Compat]  - sucompat kernel path-hook serving root (detectable)
#   [nosu]    - neither: no su path active
# Called from post-mount.sh at boot and from the WebUI when the mode changes.
D=/data/adb/modules/kernelnosu
MP="$D/module.prop"
base="KernelSU mounted su binary"

sc=$(/data/adb/ksud feature list 2>/dev/null | awk '/su_compat \(ID=0\)/{print (/ENABLED/)?"on":"off"}')
mnt=$(grep -c " /system/bin/su " /proc/self/mountinfo 2>/dev/null)

if [ "${mnt:-0}" -ge 1 ]; then
	if [ "$sc" = "off" ]; then tag="🟢 su";        sub="real su active · sucompat off"
	else                      tag="🟡 su + Compat"; sub="real su mounted · sucompat also on"; fi
elif [ "$sc" = "on" ]; then   tag="🟡 Compat";      sub="kernel path-hook (detectable)"
else                          tag="🔴 nosu";        sub="no su path active"; fi

# use | as sed delimiter so paths/spaces in the text are safe
sed -i "s|^description=.*|description=[$tag] $sub — $base|" "$MP" 2>/dev/null

# EOF
