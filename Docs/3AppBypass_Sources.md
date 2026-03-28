# 3 App Bypass — Community Sources & PoCs

Collected public resources (initial):

- `zqxwce/amfidont` — simple amfid bypass utility (GitHub): https://github.com/zqxwce/amfidont
- `ProjectManticore` — jailbreak project with historical amfid bypass references: https://github.com/ProjectManticore/Manticore
- Historical AppSync-style packages and discussions (search GitHub for AppSync / installd tweaks).
- The iPhone Wiki pages for AMFI and `installd` (background): https://www.theiphonewiki.com/wiki/AppleMobileFileIntegrity and https://www.theiphonewiki.com/wiki/Installd
- Community MobileGestalt and MobileGestalt patcher repos discovered earlier (for reference): `MGKeys`, `autoPatcher-mobilegestalt`, `MobileGestalt-hook` (search GitHub for "MobileGestalt").

Notes:
- Public PoCs exist but may not include symbol maps or offsets for iOS 18.x; many projects target older iOS versions and need per-build offsets.
- Next step: search community symbol dumps and offsets repos (e.g., `offsets` / `symbols` JSON in GitHub), or extract symbols from IPSW if unavailable.

How to contribute symbol maps:
- If you have a device or IPSW for a target build, extract `amfid`/`installd` and run `other/3app-bypass/scripts/scan_symbols.py`.
- Produce a JSON map at `/var/mobile/Library/lara/3appbypass_symbols.json` with resolved addresses for the tweak to use.
