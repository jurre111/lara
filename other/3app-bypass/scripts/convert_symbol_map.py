#!/usr/bin/env python3
"""
convert_symbol_map.py
Convert the output of resolve_addresses.sh into a device-ready JSON symbol map.

Usage: convert_symbol_map.py <resolve_output.json> <preferred_symbols.txt> <out.json>

preferred_symbols.txt is an optional newline-separated list of symbol names (in order) to prefer.
If a symbol is present in the resolver output, its hex offset will be used as-is. You may need
to add ASLR slide on-device before using absolute addresses.
"""
import sys, json, os

def load_json(p):
    with open(p,'r') as f:
        return json.load(f)

def main():
    if len(sys.argv) < 3:
        print('Usage: convert_symbol_map.py <resolve_output.json> <preferred_symbols.txt|-> <out.json>')
        sys.exit(2)
    src = sys.argv[1]
    pref_file = sys.argv[2]
    out = sys.argv[3]
    data = load_json(src)
    # data: { symbol: { filename: addr_hex, ... }, ... }
    prefs = []
    if pref_file != '-':
        with open(pref_file,'r') as f:
            prefs = [l.strip() for l in f if l.strip()]

    outmap = {}
    # For each preferred symbol, pick first file addr
    for sym in prefs:
        if sym in data:
            files = data[sym]
            # choose first filename
            fname = next(iter(files))
            outmap[sym] = files[fname]

    # Add any remaining symbols found
    for sym, files in data.items():
        if sym in outmap:
            continue
        fname = next(iter(files))
        outmap[sym] = files[fname]

    # Normalize to 0x prefix
    norm = {}
    for k,v in outmap.items():
        s = str(v)
        if not s.startswith('0x') and not s.startswith('0X'):
            try:
                s = hex(int(s,16))
            except Exception:
                # leave as-is
                pass
        norm[k] = s

    with open(out,'w') as f:
        json.dump(norm, f, indent=2)

    print('Wrote', out)

if __name__ == '__main__':
    main()
