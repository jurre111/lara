# MobileGestalt Editor — Research Notes

Goal: Add UI + backend to view and edit MobileGestalt keys on-device.

Background summary:
- MobileGestalt is an iOS system service (private API) that provides device properties (e.g., "ProductType", "SerialNumber", "RegionInfo").
- Many keys are derived from hardware, provisioning profiles, or system configuration; some are read-only without kernel or sandbox bypass.

Areas to research (next actions):
1. MobileGestalt API surfaces (libMobileGestalt, MobileGestalt.c) and how to call from Swift.
2. Which keys are stored in preferences/plists vs. derived by kernel/hardware.
3. Existing tools that patch MobileGestalt responses (MobileGestaltServer patching, jailbreak tweaks, dyld interpose approaches).
4. Feasibility of per-key runtime interception (xpc proxy, function interpose) vs. persistent system plist edits.
5. Required entitlements, sandbox/kext/kernel access, and offsets for supported iOS versions (17.5–18.6.2 baseline).

Deliverables for implementation:
- A safe read-only viewer for MobileGestalt keys.
- An edit flow that attempts non-destructive runtime overrides first (in-memory/interpose), with fallback to persistent patching when possible.
- Backend APIs in `lara` to get/set keys and to revert changes.

References (to gather):
- Apple internal docs and libMobileGestalt headers (search web)
- Jailbreak tweak sources that modify MobileGestalt
- dyld interposing examples and XPC proxy hooking patterns

Status: research started. Next: gather authoritative resources and examples.
