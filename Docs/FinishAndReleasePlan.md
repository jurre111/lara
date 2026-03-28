Finish & Release Plan — lara

Goal: finish a working release that includes MobileGestalt Editor (viewer + runtime overrides + KFS persistence) and a tested 3‑App bypass prototype (daemon/tweak approach) for jailbroken devices.

Milestones (2–5 days estimate depending on device access):

1) MobileGestalt polish (0.5 day)
- Add concise logging in `MobileGestaltManager` and `MobileGestaltView` (already present).
- Ensure Save/Load/Apply show clear status and errors across cases.
- Add UI link in settings or main menu (done).

2) KFS verification & backups (0.5–1 day)
- Verify `saveOverridesToKFS`, `loadOverridesFromKFS`, `applyOverridesToSystemCache`, and restore on a test device.
- Confirm backup file exists and restore works across reboots.

3) Tests & compatibility matrix (0.5 day)
- Create manual test checklist and minimal unit tests where possible (plist serialization, override persistence).
- Document tested iOS builds and device types.

4) Tweak symbol resolution & scripts (1 day)
- Use `get_device_binaries.sh` + `scan_symbols.py` to identify candidate symbols.
- Populate `/var/mobile/Library/lara/3appbypass_symbols.json` example for target builds.
- Verify tweak hooks by address via the JSON map.

5) Prototype and test tweak on-device (1–2 days)
- Build Theos package (`make package`), install on test device, observe logs.
- Iterate until signature checks are reliably bypassed for test bundles.
- Always keep backups and a documented rollback (restore AMFI cache + original daemon).

6) Safety, docs, and release (0.5 day)
- Add warnings, opt-in toggles, and recovery instructions to `Docs/3AppBypass_Plan.md` and `README.md`.
- Package example symbol maps under `other/3app-bypass/examples/`.
- Tag release and produce short changelog.

Quick test commands (local dev)

- Pull binaries:

```bash
./other/3app-bypass/scripts/get_device_binaries.sh root@<device_ip> ./work/binaries
```

- Scan binaries:

```bash
./other/3app-bypass/scripts/scan_symbols.py ./work/binaries/amfid ./work/binaries/installd
```

- Build tweak (on host with Theos):

```bash
cd other/3app-bypass
make package
```

Notes & warnings
- 3 App Bypass is intended for jailbroken devices only. Provide explicit warnings and require manual confirmation for any destructive actions.
- Do not attempt kernel-level patches until daemon-level prototype is exhausted; kernel patches are high-risk.

Status: plan created. Begin with MobileGestalt verification and KFS tests, then move to tweak symbol resolution.
