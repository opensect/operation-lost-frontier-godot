#!/bin/bash
# In-process LAN sync test (see tools/lan_sync_test.gd for why it is
# in-process: the sandbox blocks UDP sends, so two Godot processes can
# never complete an ENet handshake here).
# Usage: tools/run_lan_sync_test.sh [duration_seconds]
# Exits 0 on PASS, 1 on FAIL.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="$HOME/workspace/tools/godot/Godot_v4.4.1-stable_linux.x86_64"
DUR="${1:-6}"
rm -f /tmp/lan_sync.json
timeout 90 "$GODOT" --headless --path . -s res://tools/lan_sync_test.gd -- --dur="$DUR" --out=/tmp/lan_sync.json > /tmp/lan_sync.log 2>&1
EXIT=$?
grep -E "LAN SYNC|SCRIPT ERROR" /tmp/lan_sync.log
if [ "$EXIT" -ne 0 ]; then
	echo "--- log tail ---"
	tail -15 /tmp/lan_sync.log
fi
exit "$EXIT"
