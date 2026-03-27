import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared

    private let systemMGPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let origMGURL: URL
    private let modMGURL: URL

    @State private var mobileGestalt: NSMutableDictionary = [:]
    @State private var originalProductType: String = ""
    @State private var productType: String = ""
    @State private var loadError: String?
    @State private var showErrorAlert = false
    @State private var showImporter = false

    @State private var customKey = ""
    @State private var customValue = ""
    @State private var customType: CustomValueType = .string
    @State private var applyStatus: String?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        origMGURL = docs.appendingPathComponent("OriginalMobileGestalt.plist")
        modMGURL = docs.appendingPathComponent("ModifiedMobileGestalt.plist")
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("KFS Ready")
                    Spacer()
                    Text(mgr.kfsready ? "Yes" : "No")
                        .foregroundColor(mgr.kfsready ? .green : .red)
                }
            } header: {
                Text("Status")
            }

            Section {
                Toggle("Action Button", isOn: bindingForMGKeys(["cT44WE1EohiwRzhsZ8xEsw"]))
                Toggle("Allow installing iPadOS apps", isOn: bindingForMGKeys(["9MZ5AdH43csAUajl/dU+IQ"], type: [Int].self, enableValue: [1, 2]))
                Toggle("Always on Display", isOn: bindingForMGKeys(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                Toggle("Apple Intelligence", isOn: bindingForMGKeys(["A62OafQ85EJAiiqKn4agtg"]))
                Toggle("Apple Pencil", isOn: bindingForMGKeys(["yhHcB0iH0d1XzPO/CFd3ow"]))
                Toggle("Boot chime", isOn: bindingForMGKeys(["QHxt+hGLaBPbQJbXiUJX3w"]))
                Toggle("Camera button", isOn: bindingForMGKeys(["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]))
                Toggle("Charge limit", isOn: bindingForMGKeys(["37NVydb//GP/GrhuTN+exg"]))
                Toggle("Crash Detection", isOn: bindingForMGKeys(["HCzWusHQwZDea6nNhaKndw"]))
                Toggle("Dynamic Island", isOn: bindingForMGKeys(["YlEtTtHlNesRBMal1CqRaA"]))
                Toggle("Disable region restrictions", isOn: bindingForRegionRestriction())
                Toggle("Internal Storage info", isOn: bindingForMGKeys(["LBJfwOEzExRxzlAnSuI7eg"]))
                Toggle("Security Research Device", isOn: bindingForMGKeys(["XYlJKKkj2hztRP1NWWnhlw"]))
                Toggle("Metal HUD for all apps", isOn: bindingForMGKeys(["EqrsVvjcYDdxHBiQmGhAWw"]))
                Toggle("Stage Manager", isOn: bindingForMGKeys(["qeaj75wk3HF4DwQ8qbIi7g"]))
            } header: {
                Text("MobileGestalt")
            }

            Section {
                Picker("Preset", selection: $productType) {
                    Text("unchanged").tag(originalProductType.isEmpty ? productType : originalProductType)
                    Text("iPhone 15 Pro Max").tag("iPhone16,2")
                    Text("iPhone 16 Pro Max").tag("iPhone17,2")
                    Text("iPad Pro 11 inch 5th Gen").tag("iPad16,3")
                }
                TextField("Product type", text: $productType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Device Spoofing")
            } footer: {
                Text("Change the product type only when you understand the device-specific side effects.")
            }

            Section {
                TextField("Key", text: $customKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Value", text: $customValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Type", selection: $customType) {
                    ForEach(CustomValueType.allCases) { valueType in
                        Text(valueType.label).tag(valueType)
                    }
                }
                Button("Set Key") {
                    setCustomKey()
                }
                .disabled(customKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Remove Key", role: .destructive) {
                    removeCustomKey()
                }
                .disabled(customKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Custom Key")
            } footer: {
                Text("Writes to CacheExtra unless the key already exists at the top level.")
            }

            Section {
                Button("Apply changes") {
                    applyChanges()
                }
                .disabled(!mgr.kfsready)

                Button("Reset changes") {
                    resetChanges()
                }
                Button("Reload from System") {
                    reloadFromSystem()
                }
                Button("Import MobileGestalt") {
                    showImporter = true
                }
                ShareLink("Export Modified MobileGestalt", item: modMGURL)
                ShareLink("Export Original MobileGestalt", item: origMGURL)
            } header: {
                Text("Manage")
            } footer: {
                Text("Apply uses KFS overwrite on the system MobileGestalt plist.")
            }
        }
        .navigationTitle("MobileGestalt")
        .alert("MobileGestalt Error", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(loadError ?? "Unknown error")
        }
        .alert("Apply Status", isPresented: Binding(get: { applyStatus != nil }, set: { _ in applyStatus = nil })) {
            Button("OK") {}
        } message: {
            Text(applyStatus ?? "")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.propertyList, .data]) { result in
            handleImport(result)
        }
        .onAppear {
            loadMobileGestalt()
        }
    }

    private func ensureCacheExtra() -> NSMutableDictionary {
        if let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary {
            return cacheExtra
        }
        let cacheExtra = NSMutableDictionary()
        mobileGestalt["CacheExtra"] = cacheExtra
        return cacheExtra
    }

    private func bindingForMGKeys<T: Equatable>(_ keys: [String], type: T.Type = Int.self, enableValue: T? = 1) -> Binding<Bool> {
        let cacheExtra = ensureCacheExtra()
        return Binding(
            get: {
                guard let enableValue else { return false }
                if let value = cacheExtra[keys.first ?? ""] as? T {
                    return value == enableValue
                }
                return false
            },
            set: { enabled in
                for key in keys {
                    if enabled {
                        cacheExtra[key] = enableValue
                    } else {
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }

    private func bindingForRegionRestriction() -> Binding<Bool> {
        let cacheExtra = ensureCacheExtra()
        return Binding(
            get: {
                return cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "US" &&
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] as? String == "LL/A"
            },
            set: { enabled in
                if enabled {
                    cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] = "US"
                    cacheExtra["zHeENZu+wbg7PUprwNwBWg"] = "LL/A"
                } else {
                    cacheExtra.removeObject(forKey: "h63QSdBCiT/z0WU6rdQv6Q")
                    cacheExtra.removeObject(forKey: "zHeENZu+wbg7PUprwNwBWg")
                }
            }
        )
    }

    private func loadMobileGestalt() {
        do {
            try bootstrapFiles()
            try loadMobileGestaltFromDisk()
        } catch {
            loadError = "Failed to load MobileGestalt: \(error)"
            showErrorAlert = true
        }
    }

    private func bootstrapFiles() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: origMGURL.path) {
            let systemURL = URL(fileURLWithPath: systemMGPath)
            guard fm.isReadableFile(atPath: systemURL.path) else {
                throw NSError(domain: "lara.mobilegestalt", code: 1, userInfo: [NSLocalizedDescriptionKey: "System MobileGestalt plist is not readable. Import a plist to continue."])
            }
            try fm.copyItem(at: systemURL, to: origMGURL)
        }
        if !fm.fileExists(atPath: modMGURL.path) {
            try fm.copyItem(at: origMGURL, to: modMGURL)
        }
    }

    private func loadMobileGestaltFromDisk() throws {
        guard let dict = NSMutableDictionary(contentsOf: modMGURL) else {
            throw NSError(domain: "lara.mobilegestalt", code: 2, userInfo: [NSLocalizedDescriptionKey: "MobileGestalt plist could not be parsed."])
        }
        mobileGestalt = dict
        if let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary,
           let model = cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String {
            originalProductType = model
            productType = model
        } else {
            let model = Self.machineName()
            originalProductType = model
            productType = model
        }
    }

    private func applyChanges() {
        saveProductType()
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: mobileGestalt, format: .xml, options: 0)
            try data.write(to: modMGURL)
            let ok = mgr.kfsoverwritewithdata(target: systemMGPath, data: data)
            applyStatus = ok ? "Applied MobileGestalt via KFS." : "Failed to overwrite MobileGestalt via KFS."
            if ok {
                mgr.logmsg("(kfs) MobileGestalt overwrite success")
            } else {
                mgr.logmsg("(kfs) MobileGestalt overwrite failed")
            }
        } catch {
            applyStatus = "Apply failed: \(error)"
        }
    }

    private func resetChanges() {
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: modMGURL.path) {
                try fm.removeItem(at: modMGURL)
            }
            try fm.copyItem(at: origMGURL, to: modMGURL)
            try loadMobileGestaltFromDisk()
            applyStatus = "Reset modified MobileGestalt to original copy."
        } catch {
            applyStatus = "Reset failed: \(error)"
        }
    }

    private func reloadFromSystem() {
        do {
            let fm = FileManager.default
            let systemURL = URL(fileURLWithPath: systemMGPath)
            guard fm.isReadableFile(atPath: systemURL.path) else {
                throw NSError(domain: "lara.mobilegestalt", code: 3, userInfo: [NSLocalizedDescriptionKey: "System MobileGestalt plist is not readable."])
            }
            if fm.fileExists(atPath: origMGURL.path) {
                try fm.removeItem(at: origMGURL)
            }
            if fm.fileExists(atPath: modMGURL.path) {
                try fm.removeItem(at: modMGURL)
            }
            try fm.copyItem(at: systemURL, to: origMGURL)
            try fm.copyItem(at: origMGURL, to: modMGURL)
            try loadMobileGestaltFromDisk()
            applyStatus = "Reloaded MobileGestalt from system copy."
        } catch {
            applyStatus = "Reload failed: \(error)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let data = try Data(contentsOf: url)
            try data.write(to: origMGURL)
            try data.write(to: modMGURL)
            try loadMobileGestaltFromDisk()
            applyStatus = "Imported MobileGestalt plist."
        } catch {
            loadError = "Import failed: \(error)"
            showErrorAlert = true
        }
    }

    private func saveProductType() {
        guard !productType.isEmpty else { return }
        let cacheExtra = ensureCacheExtra()
        cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] = productType
    }

    private func setCustomKey() {
        let trimmedKey = customKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        let value: Any
        switch customType {
        case .string:
            value = customValue
        case .int:
            if let intValue = Int(customValue) {
                value = intValue
            } else {
                applyStatus = "Invalid integer value."
                return
            }
        case .bool:
            let lowered = customValue.lowercased()
            if ["true", "1", "yes"].contains(lowered) {
                value = true
            } else if ["false", "0", "no"].contains(lowered) {
                value = false
            } else {
                applyStatus = "Invalid boolean value. Use true/false or 1/0."
                return
            }
        }

        if mobileGestalt[trimmedKey] != nil {
            mobileGestalt[trimmedKey] = value
        } else {
            let cacheExtra = ensureCacheExtra()
            cacheExtra[trimmedKey] = value
        }
        applyStatus = "Set \(trimmedKey)."
    }

    private func removeCustomKey() {
        let trimmedKey = customKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        if mobileGestalt[trimmedKey] != nil {
            mobileGestalt.removeObject(forKey: trimmedKey)
        } else {
            let cacheExtra = ensureCacheExtra()
            cacheExtra.removeObject(forKey: trimmedKey)
        }
        applyStatus = "Removed \(trimmedKey)."
    }

    private static func machineName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}

private enum CustomValueType: String, CaseIterable, Identifiable {
    case string
    case int
    case bool

    var id: String { rawValue }

    var label: String {
        switch self {
        case .string: return "String"
        case .int: return "Int"
        case .bool: return "Bool"
        }
    }
}
