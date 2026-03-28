#!/usr/bin/env bash
set -euo pipefail

# ipsw_extract.sh
# Usage: ./ipsw_extract.sh <device_identifier> <version_or_build> <output_dir>
# Example: ./ipsw_extract.sh iPhone15,3 18.0 ./out

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <device> <version_or_build> <output_dir>"
  exit 2
fi

DEVICE="$1"
VERSION="$2"
OUTDIR="$3"

for cmd in curl jq unzip 7z; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd" >&2
    echo "Install it (e.g. apt install curl jq p7zip-full) and retry." >&2
    exit 1
  fi
done

mkdir -p "$OUTDIR"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Querying ipsw.me for $DEVICE $VERSION..."
META=$(curl -s "https://api.ipsw.me/v4/ipsw/$DEVICE/$VERSION?type=ipsw")
URL=$(echo "$META" | jq -r .url)
if [ -z "$URL" ] || [ "$URL" = "null" ]; then
  echo "Could not find IPSW URL for $DEVICE $VERSION" >&2
  exit 1
fi

IPSW_NAME="$TMPDIR/$(basename "$URL")"
echo "Downloading IPSW... (this can be large)"
curl -L --progress-bar -o "$IPSW_NAME" "$URL"

echo "Extracting IPSW archive (zip) to $TMPDIR/unzip..."
mkdir -p "$TMPDIR/unzip"
unzip -q "$IPSW_NAME" -d "$TMPDIR/unzip"

# Search for DMG files inside the extracted IPSW
DMGS=( $(find "$TMPDIR/unzip" -type f -iname "*.dmg" -print) )
if [ ${#DMGS[@]} -eq 0 ]; then
  echo "No DMG files found inside IPSW. Looking for .hfs or root filesystem images..."
  DMGS=( $(find "$TMPDIR/unzip" -type f \( -iname "*.hfs" -o -iname "*.img" -o -iname "*.dmgpart" \) -print) )
fi

if [ ${#DMGS[@]} -eq 0 ]; then
  echo "No filesystem images found in IPSW; extraction on this platform may require additional tools." >&2
  exit 1
fi

mkdir -p "$OUTDIR/binaries"

for dmg in "${DMGS[@]}"; do
  echo "Processing $dmg"
  BASENAME=$(basename "$dmg")
  WORK="$TMPDIR/work_$BASENAME"
  mkdir -p "$WORK"
  cp "$dmg" "$WORK/"
  pushd "$WORK" >/dev/null

  if command -v dmg2img >/dev/null 2>&1; then
    IMG="$WORK/${BASENAME}.img"
    echo "Converting $dmg -> $IMG (dmg2img)"
    dmg2img "$BASENAME" "$IMG"
  else
    echo "dmg2img not found; attempting 7z extraction (may work for some DMGs)"
    7z x "$BASENAME" >/dev/null
    # try to locate an HFS image inside
    IMG_FILE=$(find . -type f -iname "*.img" -o -iname "*.hfs" | head -n1 || true)
    if [ -z "$IMG_FILE" ]; then
      echo "No image produced by 7z for $BASENAME; skipping." >&2
      popd >/dev/null
      continue
    fi
    IMG="$WORK/$IMG_FILE"
  fi

  # Try mounting the image (Linux) and search for amfid/installd
  MNT="$WORK/mnt"
  mkdir -p "$MNT"
  if sudo mount -o loop,ro "$IMG" "$MNT" 2>/dev/null; then
    echo "Mounted $IMG"
    # Common locations
    CANDIDATES=("$MNT/usr/libexec/amfid" "$MNT/usr/libexec/installd" "$MNT/Applications/*/usr/libexec/amfid" "$MNT/Applications/*/usr/libexec/installd")
    for p in "${CANDIDATES[@]}"; do
      for f in $p; do
        if [ -f "$f" ]; then
          echo "Found $f; copying to $OUTDIR/binaries/"
          cp -a "$f" "$OUTDIR/binaries/"
        fi
      done
    done
    sudo umount "$MNT" || true
  else
    echo "Could not mount $IMG (requires root and loop support). Trying to extract with 7z content listing..."
    # Attempt to extract files matching paths
    7z x "$IMG" -y >/dev/null || true
    POSS=( $(find . -type f -iname "amfid*" -o -iname "installd*" -print) )
    for f in "${POSS[@]}"; do
      echo "Found $f; copying to $OUTDIR/binaries/"
      cp -a "$f" "$OUTDIR/binaries/"
    done
  fi

  popd >/dev/null
done

echo "Extraction complete. Outputs (if any) in: $OUTDIR/binaries"
ls -l "$OUTDIR/binaries" || true

exit 0
