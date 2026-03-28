#!/usr/bin/env bash
set -euo pipefail

# rollback.sh
# Remove symbol map and restart affected daemons to revert tweak effects.
# Usage: ./rollback.sh <device_ip> <user>

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <device_ip> <ssh_user>"
  exit 2
fi

DEVICE="$1"
USER="$2"

ssh "${USER}@${DEVICE}" <<'SSH'
set -e
MAP=/var/mobile/Library/lara/3appbypass_symbols.json
LOG=/var/mobile/Library/lara/3appbypass.log
if [ -f "$MAP" ]; then
  sudo rm -f "$MAP"
  echo "Removed $MAP"
else
  echo "$MAP not present"
fi
# Restart services (may require root)
if pgrep -x amfid >/dev/null 2>&1; then
  sudo killall amfid || true
  echo "Restarted amfid"
fi
if pgrep -x installd >/dev/null 2>&1; then
  sudo killall installd || true
  echo "Restarted installd"
fi
# touch a log entry
echo "$(date): rollback executed" >> "$LOG"
SSH

echo "Rollback executed on ${DEVICE}. Check device log at /var/mobile/Library/lara/3appbypass.log"
