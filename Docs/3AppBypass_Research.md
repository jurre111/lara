# 3 App Bypass — Research Notes

Goal: Implement a feature to bypass the "3 App" limitation (context to confirm) and provide user controls in `lara`.

Open questions (to resolve via research):
- Confirm meaning of "3 App Bypass" in project context: does it refer to:
  - Bypassing Apple's limit on sideloaded apps with free Apple IDs (3-app limit), or
  - Bypassing App Store / Managed Device restrictions that limit installed apps, or
  - A different, project-specific restriction (ask owner if ambiguous).

Potential technical approaches:
1. Modify MobileDevice/amsd responses or provisioning checks to allow additional unsigned apps.
2. Patch system daemons that enforce app count (if present) or alter code signing checks via kernel patches.
3. Use per-app entitlements or container modifications to trick the system into treating apps differently.

Risks and prerequisites:
- Many approaches require kernel privileges and correct offsets per iOS version.
- High risk of device instability; must provide good rollback.

Next steps:
1. Confirm exact intended bypass behavior with project owner (clarify scope).
2. Search for existing bypass implementations and PoCs.
3. Map required kernel hooks / entitlements and create minimal prototype plan.

Status: research started. Next: confirm meaning and gather PoCs.
