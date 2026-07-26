#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
ELF_BINARY="su-arm"

# Auto-detect the best su target directory, preferring an already-separate
# partition over /system/bin:
# - /system/bin is extremely busy (hundreds of binaries constantly exec'd by
#   zygote/system_server), which can make the mount-tree promotion needed to
#   add a net-new file there fail to persist, and it's exactly the directory
#   some root detectors scrutinize for an "inconsistent mount" (a subtree that
#   should be uniform with the rest of /system but isn't).
# - /product, /system_ext, /vendor, /odm are already their own partition/mount
#   on modern (Treble) devices, so a module contributing new content there is
#   unremarkable - the same way other modules' /product/overlay etc. aren't
#   flagged - and each has only a handful of files, so the mount reliably
#   lands and persists.
# Not every ROM has these as real separate partitions (older/non-Treble
# builds, or ROMs that fold everything into /system) - detect_su_dir() checks
# each candidate's device number against /system's and falls back to
# /system/bin if none of them are actually separate.
detect_su_dir() {
	sysdev=$(stat -c %D /system 2>/dev/null)
	for p in /product /system_ext /vendor /odm; do
		[ -d "$p/bin" ] || continue
		pdev=$(stat -c %D "$p" 2>/dev/null)
		if [ -n "$pdev" ] && [ -n "$sysdev" ] && [ "$pdev" != "$sysdev" ]; then
			echo "$p/bin"
			return 0
		fi
	done
	echo "/system/bin"
}

# Set to "" to force the legacy hunt_min_dir strategy (Option B: obscure
# lowest-file-count dir on $PATH) instead of auto-detection.
SU_DIR=$(detect_su_dir)

if [ ! "$KSU" = true ]; then
	abort "[!] KernelSU only!"
fi

# this assumes CONFIG_COMPAT=y on CONFIG_ARM
arch=$(busybox uname -m)
echo "[+] detected: $arch"

case "$arch" in
	aarch64 | arm64 )
		ELF_BINARY="su-arm64"
		;;
	armv7l | armv8l )
		ELF_BINARY="su-arm"
		;;
	x86_64)
		ELF_BINARY="su-x64"
		;;
	*)
		abort "[!] $arch not supported!"
		;;
esac

# hunt for lowest filecount dir on $PATH

prep_custom_dir() {
	final="$1/su"
	line=$1
	if echo "$line" | grep -Eq "^/(product|vendor|odm|system_ext)/" && ! echo "$line" | grep -q "^/system/"; then
		line="/system$line"
	fi

	mkdir -p "$MODPATH/$line"
	cp -f "$MODPATH/$ELF_BINARY" "$MODPATH/$line/su"
	busybox chcon --reference="/system/bin/sh" "$MODPATH/$line/su"
	chmod 755 "$MODPATH/$line/su"
	echo "[+] su will be on $line/su"

	# Persist the final, real (non-rewritten) mount path AND the module's own
	# storage path for it, so every other script (harden.sh, verify.sh,
	# set_desc.sh, boot-completed.sh) and the companion metamodule read the
	# SAME two paths instead of each hardcoding /product/bin/su - keeps them
	# all correct regardless of which partition auto-detection picked.
	echo "$final" > "$MODPATH/su_target"
	echo "${line#/}/su" > "$MODPATH/su_source"
}

# small snippet that hunts for folder in $PATH that has lowest number of files!
# IFS=":" ; for i in $PATH; do [ -d $i ] && find $i -type f | wc -l ; done ??
hunt_min_dir () {
IFS_old=$IFS
IFS=":" 
	min=99999
	min_dir=""

	for i in $PATH; do
		# https://github.com/5ec1cff/KernelSU/blob/main/userspace/ksud/src/installer.sh#L392
		# only allow magic mount-able paths
		echo "$i" | grep -qE "^/system/|^/vendor/|^/product/|^/system_ext/" || continue
		[ -d "$i" ] || continue

		count=$(busybox find "$i" -type f 2>/dev/null | wc -l)
		# debug
		echo "[-] $count $i"
		if [ "$count" -lt "$min" ]; then
			min=$count
			min_dir=$i
		fi
	done

	echo "[+] lowest file count dir: $min_dir ($min files)"
	
# reset IFS
IFS=$IFS_old

	prep_custom_dir "$min_dir"

}

# test teh feature
busybox chmod +x "$MODPATH/$ELF_BINARY"

# test ksud if it has a way to disable
if [ "$KSU" = "true" ] && [ "$KSU_KERNEL_VER_CODE" -ge 22004 ]; then
	# distinguish a clobbered ksud (e.g. a susfs module overwrote it) from a
	# manager that genuinely lacks the su_compat feature
	if ! /data/adb/ksud -V 2>/dev/null | grep -qiE "ksud|uapi"; then
		abort "[!] /data/adb/ksud is not responding as ksud (clobbered?) - reinstall/open your root manager to restore it, then flash again"
	fi
	/data/adb/ksud feature list 2>/dev/null | grep -q su_compat || abort "[!] su_compat feature not available on this manager"
fi

# Stage the su binary under $MODPATH/system/<partition>/bin/su (via
# prep_custom_dir's rewrite for non-/system targets). This is a NORMAL module
# file - mounted by whatever mount backend is active (plain ksud or a
# metamodule) exactly like any other module's content for that partition. No
# skip_mount, no self-mount plumbing needed.
if [ -n "$SU_DIR" ]; then
	echo "[+] auto-detected target: $SU_DIR"
	prep_custom_dir "$SU_DIR"
else
	hunt_min_dir
fi

# Disabling sucompat before the mount (so /system/bin/su has no spoof) and
# self-healing if the real su doesn't land are handled by the mount backend
# itself when it is kernelnosu-aware (this fork's metamodule calls
# knsu_pre_mount/knsu_post_mount around the mount). On a backend that ISN'T
# kernelnosu-aware, post-fs-data.sh below still disables sucompat as a
# best-effort (harmless no-op if something else already did).

# card badge until the first boot applies the live su mode (service.sh)
sed -i "s|^description=.*|description=[⏳ reboot to activate] real su replaces sucompat — KernelSU su binary|" "$MODPATH/module.prop" 2>/dev/null

# shield ksud from susfs-module binary installers right now (install-time), so
# it's protected even before the first reboot. No-op unless vulnerable.
[ -f "$MODPATH/ksud_guard.sh" ] && sh "$MODPATH/ksud_guard.sh"

# EOF
