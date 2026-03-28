# ThreeAppBypass tweak

Overview
- Tweak prototype to allow hooking amfid/installd verification functions by symbol name or absolute address.

Build & Install
- Requires Theos on the build host.

Example build (from repo root):

```bash
cd other/3app-bypass
export THEOS=/opt/theos   # or pass THEOS env
make package
```

Install to device (scp/ssh):

```bash
./scripts/install_tweak.sh <device_ip> <ssh_user> [theos_root]
```

Generating symbol map
- Use `ipsw_extract.sh` to extract candidate binaries from an IPSW.
- Use `resolve_addresses.sh` to get per-file symbol offsets.
- Run `scripts/convert_symbol_map.py` to pick addresses and produce `/var/mobile/Library/lara/3appbypass_symbols.json` for the device.

Rollback
- Use `scripts/rollback.sh <device_ip> <ssh_user>` to remove the map and restart daemons.

Notes
- You must supply correct addresses for your target iOS build. Offsets from local binaries may require ASLR slide correction on device.
- This tweak is experimental; use with caution and backup device data.
# 3 App Bypass — Theos Tweak Skeleton

This folder contains a minimal MobileSubstrate/Theos tweak skeleton to prototype daemon-level patches for the 3‑app sideload bypass (amfid/installd).

Files:
- `Tweak.xm` — tweak implementation template (hooks and logging).
- `Makefile` — Theos package Makefile skeleton.

Notes:
- This is only a scaffold. You must fill in correct symbol names and addresses per iOS build.
- Testing requires a jailbroken device and Theos/toolchain installed.
- Keep patches minimal and reversible; always backup original binaries and AMFI caches before applying.

Next steps:
1. Obtain symbol lists for `amfid`/`installd` on target iOS builds.
2. Replace placeholder function names in `Tweak.xm` with actual targets.
3. Build and test on a device with logging enabled.

Symbol map workflow
- Use `other/3app-bypass/scripts/get_device_binaries.sh` to pull `amfid`/`installd` from a jailbroken device.
- Run `other/3app-bypass/scripts/scan_symbols.py` on the pulled binaries to find candidate symbol names or strings.
- If you can resolve an absolute address for the target function (per iOS build), create `/var/mobile/Library/lara/3appbypass_symbols.json` on the device with the mapping, e.g.:

```json
{
	"verify_fn": "0xFFFFFF8001234567"
}
```

The tweak will attempt to read that file at startup and hook by address. If no map is present, it tries dlsym with placeholder symbol names.
