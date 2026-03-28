#!/usr/bin/env bash
set -euo pipefail

# install_tweak.sh
# Builds the Theos package (if THEOS is configured) and installs it on a device via scp+ssh.
# Usage: ./install_tweak.sh <device_ip> <user> <path_to_theos_root_optional>

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <device_ip> <ssh_user> [theos_root]"
  exit 2
fi

DEVICE="$1"
USER="$2"
THEOS_ROOT="${3:-$THEOS}"

if [ -z "$THEOS_ROOT" ]; then
  echo "THEOS root not provided and THEOS env not set. Build on a host with Theos installed or set THEOS." >&2
  echo "You can still copy a prebuilt .deb with scp." >&2
fi

pushd "$(dirname "$0")/.." >/dev/null
# Build package if THEOS is available
if [ -n "$THEOS_ROOT" ] && [ -d "$THEOS_ROOT" ]; then
  echo "Building package with Theos at $THEOS_ROOT"
  export THEOS="$THEOS_ROOT"
  if ! command -v make >/dev/null 2>&1; then
    echo "make not found; ensure make and Theos are installed on the build host." >&2
    exit 1
  fi
  make package || { echo "Make failed"; exit 1; }
else
  echo "Skipping build; THEOS not set or not found. Looking for existing .deb..."
fi

DEB=$(find . -maxdepth 2 -type f -name "*.deb" | head -n1 || true)
if [ -z "$DEB" ]; then
  echo "No .deb package found. Build it on a host with Theos or provide .deb manually." >&2
  exit 1
fi

echo "Copying $DEB to ${USER}@${DEVICE}:/tmp/"
scp "$DEB" "${USER}@${DEVICE}:/tmp/"

echo "Installing package on device..."
ssh "${USER}@${DEVICE}" "sudo dpkg -i /tmp/$(basename "$DEB") && /bin/rm -f /tmp/$(basename "$DEB")"

echo "Installation attempt finished."
popd >/dev/null
