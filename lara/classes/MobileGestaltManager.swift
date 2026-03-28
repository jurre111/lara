import Foundation
import Combine

@objcMembers
public class MobileGestaltManager: ObservableObject {
    public struct Entry: Identifiable {
        public let id = UUID()
        public let key: String
        public let value: String
    }

    @Published public private(set) var entries: [Entry] = []

    // A short curated list of common MobileGestalt keys to display by default.
    public let defaultKeys: [String] = [
        "ProductType",
        "ProductVersion",
        "DeviceName",
        "SerialNumber",
        "RegionInfo",
        "HardwareModel",
        "BuildVersion",
        "BoardID",
        "ModelNumber",
        "CPUArchitecture"
    ]

    public init() {}
    private let overridesKey = "MGOverrides"
    private var overrides: [String: String] = [:]
    private let kfsOverridesPath = "/var/mobile/Library/lara/mobilegestalt_overrides.plist"

    public init() {
        loadOverrides()
    }

    public func refresh(keys: [String]? = nil) {
        let keysToFetch = keys ?? defaultKeys
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [Entry] = []
            for k in keysToFetch {
                let v = self.getValue(for: k) ?? "<nil>"
                results.append(Entry(key: k, value: v))
            }
            DispatchQueue.main.async {
                self.entries = results
            }
        }
    }

    // Returns override if present, otherwise asks MobileGestalt
    public func getValue(for key: String) -> String? {
        if let o = overrides[key] {
            return o
        }
        return MGCopyAnswerString(key)
    }

    public func setOverride(key: String, value: String) {
        overrides[key] = value
        saveOverrides()
        refresh()
    }

    public func removeOverride(key: String) {
        overrides.removeValue(forKey: key)
        saveOverrides()
        refresh()
    }

    private func saveOverrides() {
        UserDefaults.standard.set(overrides, forKey: overridesKey)
        UserDefaults.standard.synchronize()
    }

    private func loadOverrides() {
        if let d = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] {
            overrides = d
        }
    }

    // Persist overrides into KFS at `kfsOverridesPath`
    public func saveOverridesToKFS() -> Bool {
        guard laramgr.shared.kfsready else { return false }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: overrides, format: .xml, options: 0) else {
            return false
        }
        return laramgr.shared.kfsoverwritewithdata(target: kfsOverridesPath, data: data)
    }

    // Load overrides from KFS file into memory
    public func loadOverridesFromKFS() -> Bool {
        guard let d = laramgr.shared.kfsread(path: kfsOverridesPath) else { return false }
        if let obj = try? PropertyListSerialization.propertyList(from: d, options: [], format: nil) as? [String: String] {
            overrides = obj
            saveOverrides() // persist locally as well
            refresh()
            return true
        }
        return false
    }

    // Return current in-memory overrides
    public func getCurrentOverrides() -> [String: String] {
        return overrides
    }

    // Verify a key exists in the system MobileGestalt cache stored on disk (via KFS)
    public func verifyKeyInSystemCache(key: String) -> Bool? {
        let systemPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard laramgr.shared.kfsready else { return nil }
        guard let data = laramgr.shared.kfsread(path: systemPath) else { return nil }
        guard let mg = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return nil }
        let cacheExtra = mg["CacheExtra"] as? [String: Any] ?? [:]
        return cacheExtra[key] != nil
    }

    // Apply current overrides to MobileGestalt system cache plist via KFS
    public func applyOverridesToSystemCache() -> Bool {
        // system cache path used by EditorView
        let systemPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard laramgr.shared.kfsready else { return false }
        guard let data = laramgr.shared.kfsread(path: systemPath) else { return false }
        // Backup original to KFS before modifying
        let backupPath = "/var/mobile/Library/lara/mobilegestalt_backup.plist"
        _ = laramgr.shared.kfsoverwritewithdata(target: backupPath, data: data)

        guard var mg = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]) else { return false }

        var cacheExtra = mg["CacheExtra"] as? [String: Any] ?? [:]
        for (k, v) in overrides {
            cacheExtra[k] = v
        }
        mg["CacheExtra"] = cacheExtra

        guard let out = try? PropertyListSerialization.data(fromPropertyList: mg, format: .xml, options: 0) else { return false }
        return laramgr.shared.kfsoverwritewithdata(target: systemPath, data: out)
    }

    // Restore backup from KFS to system cache
    public func restoreSystemCacheFromBackup() -> Bool {
        let systemPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        let backupPath = "/var/mobile/Library/lara/mobilegestalt_backup.plist"
        guard laramgr.shared.kfsready else { return false }
        guard let data = laramgr.shared.kfsread(path: backupPath) else { return false }
        return laramgr.shared.kfsoverwritewithdata(target: systemPath, data: data)
    }

    // Remove the stored backup
    public func removeBackup() -> Bool {
        // Overwrite with empty data to delete (kfsoverwritewithdata doesn't delete). Instead, write a zero-byte file.
        let backupPath = "/var/mobile/Library/lara/mobilegestalt_backup.plist"
        guard laramgr.shared.kfsready else { return false }
        return laramgr.shared.kfsoverwritewithdata(target: backupPath, data: Data())
    }
}
