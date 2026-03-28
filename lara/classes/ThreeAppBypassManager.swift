import Foundation
import Combine

final class ThreeAppBypassManager: ObservableObject {
    static let shared = ThreeAppBypassManager()
    @Published var status: String = "idle"
    @Published var lastError: String?

    private init() {}

    struct PatchEntry: Codable {
        var type: String // "file_patch" currently
        var target: String
        var offset: String? // hex like 0x123 or decimal
        var data_hex: String? // hex string like "deadbeef"
    }

    struct PatchSet: Codable {
        var name: String?
        var entries: [PatchEntry]
    }

    func loadPatch(from path: String) -> PatchSet? {
        guard let d = laramgr.shared.kfsread(path) else {
            lastError = "Could not read patch file at \(path)"
            return nil
        }
        do {
            let ps = try JSONDecoder().decode(PatchSet.self, from: d)
            return ps
        } catch {
            lastError = "Failed to decode patch JSON: \(error)"
            return nil
        }
    }

    func apply(patch: PatchSet, backupPrefix: String = "/var/mobile/Library/lara/backups/3appbypass") {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.status = "applying" }
            for entry in patch.entries {
                if entry.type == "file_patch" {
                    guard let target = entry.target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }
                    // Read original
                    guard let orig = laramgr.shared.kfsread(path: entry.target) else {
                        DispatchQueue.main.async { self.lastError = "Could not read target \(entry.target)"; self.status = "error" }
                        return
                    }
                    // Backup
                    let bakdir = backupPrefix
                    let bakname = (entry.target as NSString).lastPathComponent + ".bak"
                    let bakpath = bakdir + "/" + bakname
                    _ = laramgr.shared.kfswrite(path: bakpath, data: orig)

                    // Modify bytes
                    guard let offS = entry.offset, let dataHex = entry.data_hex else {
                        DispatchQueue.main.async { self.lastError = "Missing offset/data for entry \(entry.target)"; self.status = "error" }
                        return
                    }
                    let off = ThreeAppBypassManager.parseNumber(offS)
                    guard off >= 0 else {
                        DispatchQueue.main.async { self.lastError = "Invalid offset \(offS)"; self.status = "error" }
                        return
                    }
                    guard let patchBytes = ThreeAppBypassManager.dataFromHexString(dataHex) else {
                        DispatchQueue.main.async { self.lastError = "Invalid hex data"; self.status = "error" }
                        return
                    }

                    var newdata = Data(orig)
                    if Int(off) + patchBytes.count > newdata.count {
                        // Extend
                        newdata.append(Data(repeating: 0, count: Int(off) + patchBytes.count - newdata.count))
                    }
                    newdata.replaceSubrange(Int(off)..<Int(off)+patchBytes.count, with: patchBytes)

                    // Write back
                    let ok = laramgr.shared.kfsoverwritewithdata(target: entry.target, data: newdata)
                    if !ok {
                        DispatchQueue.main.async { self.lastError = "Write failed for \(entry.target)"; self.status = "error" }
                        return
                    }
                } else {
                    // unsupported
                    DispatchQueue.main.async { self.lastError = "Unsupported patch type: \(entry.type)"; self.status = "error" }
                    return
                }
            }
            DispatchQueue.main.async { self.status = "applied" }
        }
    }

    func restoreBackup(backupPrefix: String = "/var/mobile/Library/lara/backups/3appbypass") {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { self.status = "restoring" }
            guard let list = laramgr.shared.kfslistdir(path: backupPrefix) else {
                DispatchQueue.main.async { self.lastError = "No backups found"; self.status = "error" }
                return
            }
            for item in list {
                if !item.isDir && item.name.hasSuffix(".bak") {
                    let bakpath = backupPrefix + "/" + item.name
                    guard let data = laramgr.shared.kfsread(path: bakpath) else { continue }
                    // infer original filename from bak name
                    let origname = String(item.name.dropLast(4))
                    // attempt to find full path by scanning common paths
                    let candidates = ["/usr/libexec/\(origname)", "/usr/sbin/\(origname)", "/usr/bin/\(origname)", "/usr/lib/\(origname)"]
                    var restored = false
                    for cand in candidates {
                        if laramgr.shared.kfssize(path: cand) >= 0 {
                            _ = laramgr.shared.kfsoverwritewithdata(target: cand, data: data)
                            restored = true
                            break
                        }
                    }
                    if !restored {
                        // write backup next to original path if unknown
                        _ = laramgr.shared.kfswrite(path: "/var/mobile/Library/lara/restored_\(origname)", data: data)
                    }
                }
            }
            DispatchQueue.main.async { self.status = "restored" }
        }
    }

    static func parseNumber(_ s: String) -> Int64 {
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            return Int64(strtoll(s, nil, 16))
        }
        return Int64(s) ?? -1
    }

    static func dataFromHexString(_ s: String) -> Data? {
        var hex = s
        if hex.hasPrefix("0x") { hex = String(hex.dropFirst(2)) }
        if hex.count % 2 != 0 { hex = "0" + hex }
        var data = Data(capacity: hex.count/2)
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            let byteStr = hex[i..<j]
            if let b = UInt8(byteStr, radix: 16) {
                data.append(b)
            } else {
                return nil
            }
            i = j
        }
        return data
    }
}
