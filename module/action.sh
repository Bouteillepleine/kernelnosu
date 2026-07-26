#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
MODDIR=${0%/*}

# ── What this action does ─────────────────────────────────────────────
# Installs a Termux `pm` wrapper. A real su (unlike the sucompat path-hook)
# does not relabel the pts, so Termux's `pm`/`am` can hang reading stdin.
# The wrapper calls the system pm with stdin closed:
#   out="$(/system/bin/pm "$@" 2>&1 </dev/null)"; echo "$out"
# Only needed if you use Termux as root; harmless otherwise.
# credit: agnostic-apollo, termux-packages#8292
# ──────────────────────────────────────────────────────────────────────

echo "[*] KernelNoSU action - install Termux pm wrapper"
echo "    fixes 'pm' inside Termux when using real su instead of sucompat"
echo ""

WRAPPER="IyEvYmluL3NoCm91dD0iJCgvc3lzdGVtL2Jpbi9wbSAiJEAiIDI+JjEgPC9kZXYvbnVsbCkiCmVjaG8gIiRvdXQiCiMgRU9GCg=="
TARGET="/data/data/com.termux/files/usr/bin/pm"

if [ -f "$TARGET" ] ; then
	want="$(echo "$WRAPPER" | busybox base64 -d | busybox crc32)"
	if [ "$want" = "$(busybox crc32 < "$TARGET")" ]; then
		echo "[=] Termux pm wrapper already installed"
	else
		echo "$WRAPPER" | busybox base64 -d > "$TARGET"
		if [ "$want" = "$(busybox crc32 < "$TARGET")" ]; then
			echo "[+] Termux pm wrapper installed at $TARGET"
		else
			echo "[!] wrapper write failed (crc mismatch)"
		fi
	fi
else
	echo "[-] Termux not found - nothing to do (this action is Termux-only)"
fi

sleep 2

# EOF
