# 3 App Bypass — Implementation Plan (sideload 3‑app limit)

Goal
- Provide a jailbroken-device feature to bypass Apple's 3‑app sideload limit so users can install more than three sideloaded apps via free provisioning approaches.

Summary of approaches

A) User-level tooling (low-risk)
- Use or integrate with AltStore/AltServer workflows to avoid the limit (refresh provisioning, re-sign apps periodically).
- Pros: safe, no kernel/daemon patching. Cons: limited automation and needs a companion host app.

B) Daemon-level patch (medium-risk, recommended first prototype)
- Target daemons that enforce installation/validation (primarily `installd`, `installcoordination`, and related processes) and intercept logic that rejects additional installations.
- Alternatively, patch `amfid` to accept unsigned/modified signatures for selected bundles.
- Pros: precise, can be scoped to specific processes or bundle IDs. Cons: requires jailbreak (code injection or tweaks), reverse-engineering per iOS version.

C) Kernel-level bypass (high-risk)
- Patch AMFI kernel enforcement (AppleMobileFileIntegrity) or code-signing enforcement points in kernel/kexts to globally disable signing/count checks.
- Pros: broad coverage. Cons: highest risk, version-specific offsets, dangerous if incorrect (can brick device).

Recommended path
1. Prototype a daemon-level tweak that hooks `amfid` or `installd` behavior for the install/validation code path used during sideload with free developer provisioning. This mirrors historical approaches (AppSync-style) and avoids direct kernel patches.
2. Provide a conservative UI to enable/disable the bypass per-app and to create automatic rollback (restore original binaries or restart daemons).
3. If daemon patching proves insufficient (server-side checks or external enforcement), evaluate a narrowly scoped kernel patch with extensive backups and explicit user warnings.

Required components
- Jailbreak or kernel write primitives from `lara` (for persistent patching and overwriting system files).
- Offset mapping for target iOS versions (function addresses in `amfid`/`installd`/kernel). Keep an offsets checklist per iOS build.
- A tweak skeleton to inject code into `amfid`/`installd` (Theos/MobileSubstrate or Substitute) with per-OS symbol resolution.
- Safe backup & revert: backup original daemons/binaries and the AMFI cache before applying changes.

Known references / PoCs
- AppSync-style packages (historical jailbreak solutions that allow unsigned apps).
- ProjectManticore / amfid bypass PoCs on GitHub (search results: ProjectManticore, amfidont).
- The iPhone Wiki entries for `AMFI` and `installd` describing historical approaches.
- AltStore (non-jailbreak sideload alternative) for user-level strategy.

Testing and safety
- Only enable bypass on confirmed jailbroken devices; detect jailbreak early and refuse on stock devices.
- Create an explicit backup before modifying any system binary or the code-sign trust cache. Provide a one-tap restore.
- Test across a small matrix of iOS builds (17.5–18.6.2 baseline as with `lara`) and device types.

Next steps (immediate)
1. Locate and extract `amfid`/`installd` symbols for target iOS builds (requires device access or symbol dumps). Produce a short list of candidate functions to hook.
2. Scaffold a MobileSubstrate tweak skeleton that logs calls and can return a forced "valid" result for signature checks in-process.
3. Validate the tweak on a test device and implement safe revert.

Helpers added
- `other/3app-bypass/scripts/get_device_binaries.sh` — SCP helper to pull binaries from a jailbroken device.
- `other/3app-bypass/scripts/scan_symbols.py` — scan local binaries for likely amfid/installd/AMFI-related symbols using `nm`/`otool`/`strings`.

Usage examples
- Pull binaries from device:

```bash
./other/3app-bypass/scripts/get_device_binaries.sh root@192.168.1.42 ./work/binaries
```

- Scan the pulled binaries:

```bash
./other/3app-bypass/scripts/scan_symbols.py ./work/binaries/amfid ./work/binaries/installd
```


Notes
- This feature is intended for jailbroken devices only. It may violate App Store/Apple policies if used to distribute apps circumventing platform protections; include clear warnings and an opt-in flow.
- Keep patches minimal and reversible.

Status: plan created. Next: scaffold tweak skeleton and start identifying amfid/installd symbols on-device.
