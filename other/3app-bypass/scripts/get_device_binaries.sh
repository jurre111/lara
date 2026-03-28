#!/usr/bin/env bash
# Pull amfid/installd binaries from a jailbroken device over SSH.
# Usage: ./get_device_binaries.sh <user@device_ip> <output_dir>

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <user@device_ip> <output_dir>"
  exit 1
fi

DEST="$2"
REMOTE="$1"

mkdir -p "$DEST"

# Common paths (may vary by device / iOS version)
declare -a PATHS=(
  "/usr/libexec/amfid"
  "/usr/sbin/installd"
  "/usr/libexec/installd"  # alternative
)

for p in "${PATHS[@]}"; do
  echo "Attempting to copy $p from $REMOTE..."
  scp -q "$REMOTE:$p" "$DEST/" || echo "Failed to copy $p"
done

echo "Done. Files in: $DEST"
