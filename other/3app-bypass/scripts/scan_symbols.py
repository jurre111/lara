#!/usr/bin/env python3
"""
Scan given Mach-O binaries for likely code-sign / AMFI / install-related symbols.
Usage: ./scan_symbols.py /path/to/amfid /path/to/installd

This script tries to use available tooling (`nm`, `otool`) and falls back to simple grep of strings.
"""

import shutil
import subprocess
import sys
from pathlib import Path

KEY_TERMS = [
    "amfid",
    "AMFI",
    "cs_validate",
    "csops",
    "cs_enforcement",
    "validate",
    "verify",
    "install",
    "installd",
    "signature",
    "codesign",
    "trustcache",
    "binary_trust",
    "CheckSignature",
]


def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode(errors='ignore')
    except Exception:
        return ""


def symbols_with_nm(path: Path):
    out = run_cmd(["nm", "-gU", str(path)])
    return out


def otool_symbols(path: Path):
    out = run_cmd(["otool", "-Iv", str(path)])
    return out


def strings_search(path: Path):
    out = run_cmd(["strings", str(path)])
    return out


def scan(path: Path):
    print(f"\nScanning: {path}")
    found = set()

    if shutil.which("nm"):
        s = symbols_with_nm(path)
        for t in KEY_TERMS:
            if t.lower() in s.lower():
                found.add(("nm", t))

    if shutil.which("otool"):
        s = otool_symbols(path)
        for t in KEY_TERMS:
            if t.lower() in s.lower():
                found.add(("otool", t))

    # fallback to strings
    s = strings_search(path)
    for t in KEY_TERMS:
        if t.lower() in s.lower():
            found.add(("strings", t))

    if found:
        print("Likely matches:")
        for src, term in sorted(found):
            print(f" - {term} (matched in {src})")
    else:
        print("No obvious matches found for key terms; inspect binary manually.")


def main():
    if len(sys.argv) < 2:
        print("Usage: scan_symbols.py <binary> [binary2 ...]")
        sys.exit(2)

    for p in sys.argv[1:]:
        path = Path(p)
        if not path.exists():
            print(f"File not found: {p}")
            continue
        scan(path)


if __name__ == "__main__":
    main()
