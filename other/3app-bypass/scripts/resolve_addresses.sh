#!/usr/bin/env bash
set -euo pipefail

# resolve_addresses.sh
# Usage: ./resolve_addresses.sh <binaries_dir> <output.json>
# Scans binaries for exported/global symbols and produces a JSON mapping of symbol->offset.

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <binaries_dir> <output.json>"
  exit 2
fi

BINDIR="$1"
OUTFILE="$2"

if [ ! -d "$BINDIR" ]; then
  echo "Binaries dir not found: $BINDIR" >&2
  exit 1
fi

python3 - <<'PY'
import sys, subprocess, json, os, shlex
bindir = sys.argv[1]
out = sys.argv[2]

symbols = {}

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode('utf-8')
    except Exception:
        return ''

for fname in os.listdir(bindir):
    path = os.path.join(bindir, fname)
    if not os.path.isfile(path):
        continue
    # Try llvm-nm, nm, or dump
    outp = run_cmd(f"llvm-nm -n {shlex.quote(path)} 2>/dev/null")
    if not outp:
        outp = run_cmd(f"nm -n {shlex.quote(path)} 2>/dev/null")
    if not outp:
        outp = run_cmd(f"objdump -t {shlex.quote(path)} 2>/dev/null")
    if not outp:
        # skip if no tool could read symbols
        continue
    for line in outp.splitlines():
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        # Try to parse lines like: <addr> <type> <name>
        addr = parts[0]
        name = parts[-1]
        # filter non-symbol names
        if name.startswith('_'):
            sym = name.lstrip('_')
            try:
                addr_int = int(addr, 16)
            except Exception:
                continue
            # Record offset relative to file (note: not slid/absolute on-device)
            symbols.setdefault(sym, {})[fname] = hex(addr_int)

with open(out, 'w') as f:
    json.dump(symbols, f, indent=2)

print(f"Wrote {out} with {len(symbols)} symbols")
PY
