//
//  EditorView.swift
//  lara
//
//  Created by ruter on 27.03.26.
//

// Most of the code is from Duy's SparseBox
// thank you @jurre111

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var mg: NSMutableDictionary
    @State private var status: String?
    @State private var alert: String?
    @State private var valid: Bool = true
    @AppStorage("ogSubType") private var ogSubType: Int = -1
    @State private var selectedSubType: Int = -1
    @State private var backupFound: Bool?
    @State private var backupValid: Bool?
    @State private var firstLoad: Bool = true
    @State private var showimporter: Bool = false
    @AppStorage("firstMGLoad") private var firstMGLoad: Bool = true

    enum SubType: Int, CaseIterable, Identifiable {
        case iPhone14Pro = 2556
        case iPhone14ProMax = 2796
        case iPhone16Pro = 2622
        case iPhone16ProMax = 2868
        // X gestures for SE?

        var id: Int { self.rawValue }
        var displayName: String {
            switch self {
            case .iPhone14Pro: return "14 Pro (2556)"
            case .iPhone14ProMax: return "14 Pro Max (2796)"
            case .iPhone16Pro: return "iOS 18+:\n16 Pro (2622)"
            case .iPhone16ProMax: return "iOS 18+:\n16 Pro Max (2868)"
            }
        }
    }
    
    private let path = "/var/mobile/Documents/mbg.plist" // "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let ogmgurl: URL
    let os = ProcessInfo().operatingSystemVersion
    private let secondBackupURL = URL(fileURLWithPath: "/var/mobile/.lara/ogmobilegestalt.plist")
    private let fm = FileManager.default

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ogmgurl = docs.appendingPathComponent("ogmobilegestalt.plist")
        let sysurl = URL(fileURLWithPath: path)
        do {
            _mg = State(initialValue: try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ()))
        } catch {
            _mg = State(initialValue: [:])
        }
        guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary, let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
            return
        }
        guard let subType = oPeik["ArtworkDeviceSubType"] as? Int else {
            return
        }
        _selectedSubType = State(initialValue: subType)
        // This only happens on the first load
        if ogSubType == -1 {
            ogSubType = subType
        }

    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Dynamic Island")
                        
                        Spacer()
                        
                        Picker("", selection: $selectedSubType) {
                            Text("Original (\(String(ogSubType)))").tag(ogSubType)
                            ForEach(SubType.allCases.filter { $0.rawValue != ogSubType }) { subtype in
                                Text(subtype.displayName).tag(subtype.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle("Action Button", isOn: mgkeybinding(["cT44WE1EohiwRzhsZ8xEsw"]))
                        .disabled(requiresVersion(17))
                    Toggle("Allow installing iPadOS apps", isOn: mgkeybinding(["9MZ5AdH43csAUajl/dU+IQ"], type: [Int].self, default: [1], enable: [1, 2]))
                    Toggle("Always on Display (18.0+)", isOn: mgkeybinding(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                        .disabled(requiresVersion(18))
                    // Toggle("Apple Intelligence", isOn: bindingForAppleIntelligence())
                    //    .disabled(requiresVersion(18))
                    Toggle("Apple Pencil", isOn: mgkeybinding(["yhHcB0iH0d1XzPO/CFd3ow"]))
                    Toggle("Boot chime", isOn: mgkeybinding(["QHxt+hGLaBPbQJbXiUJX3w"]))
                    Toggle("Camera button (18.0rc+)", isOn: mgkeybinding(["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]))
                        .disabled(requiresVersion(18))
                    Toggle("Charge limit (17+)", isOn: mgkeybinding(["37NVydb//GP/GrhuTN+exg"]))
                    .   disabled(requiresVersion(17))
                    Toggle("Crash Detection (might not work)", isOn: mgkeybinding(["HCzWusHQwZDea6nNhaKndw"]))
                    // Toggle("Dynamic Island (17.4+, might not work)", isOn: mgkeybinding(["YlEtTtHlNesRBMal1CqRaA"]))
                    // Toggle("Disable region restrictions", isOn: bindingForRegionRestriction())
                    Toggle("Internal Storage info", isOn: mgkeybinding(["LBJfwOEzExRxzlAnSuI7eg"]))
                    // Toggle("Internal stuff", isOn: bindingForInternalStuff())
                    Toggle("Security Research Device", isOn: mgkeybinding(["XYlJKKkj2hztRP1NWWnhlw"]))
                    Toggle("Metal HUD for all apps", isOn: mgkeybinding(["EqrsVvjcYDdxHBiQmGhAWw"]))
                    Toggle("Stage Manager", isOn: mgkeybinding(["qeaj75wk3HF4DwQ8qbIi7g"]))
                        .disabled(UIDevice.current.userInterfaceIdiom != .pad)
                    if UIDevice._hasHomeButton() {
                        Toggle("Tap to Wake (iPhone SE)", isOn: mgkeybinding(["yZf3GTRMGTuwSV/lD7Cagw"]))
                    }
                } header: {
                    Text("MobileGestalt")
                } footer: {
                    Text("Note: some tweaks may not work or cause instability.\nWARNING: Never enable features your device doesn't support.")
                }
                Section {
                    let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary
                    Toggle("Become iPadOS", isOn: bindingForTrollPad())
                    // validate DeviceClass
                        .disabled(cacheExtra?["+3Uf0Pm5F8Xy7Onyvko0vA"] as? String != "iPhone")
                } footer: {
                    Text("Override user interface idiom to iPadOS, so you could use all iPadOS multitasking features on iPhone. Gives you the same capabilities as TrollPad, but may cause some issues.\nPLEASE DO NOT TURN OFF SHOW DOCK IN STAGE MANAGER OTHERWISE YOUR PHONE WILL BOOTLOOP WHEN ROTATING TO LANDSCAPE.")
                }
                Section {
                    HStack {
                        Text("Status")
                        
                        Spacer()
                        
                        if valid {
                            Text("valid!")
                                .monospaced(true)
                                .foregroundColor(.green)
                        } else {
                            Text("invalid.")
                                .monospaced(true)
                                .foregroundColor(.red)
                        }
                    }
                    Button() {
                        load()
                    } label: {
                        Text("Reload from plist")
                    }
                    Button() {
                        apply()
                    } label: {
                        Text("Apply Modified MobileGestalt")
                    }
                    .disabled(!valid)
                } header: {
                    Text("Apply")
                } footer: {
                    Text("Use at your own risk. Always keep a backup of your MobileGestalt somewhere safe.")
                }

                Section {
                    NavigationLink {
                        List {
                            Section {
                                HStack {
                                    Text("Backups Status")
                                    Spacer()
                                    if backupValid == true {
                                        Text("valid!")
                                            .monospaced(true)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("invalid.")
                                            .monospaced(true)
                                            .foregroundColor(.red)
                                    }
                                }
                                Button() {
                                    checkBackups()
                                } label: {
                                    Text("Reload")
                                }
                                Button() {
                                    mgr.logmsg("(mbg) Uploading backup from files...")
                                    showimporter = true
                                } label: {
                                    Text("Import backup from files")
                                        .foregroundColor(.red)
                                }
                            } header: {
                                Text("Backup Manager")
                            } footer: {
                                Text("You can upload your own backup from files if your current backups are invalid or not the true original. Be aware that this overrides your current backups. This cannot be restored.")
                            }
                        }
                    } label: {
                        HStack {
                            Text("Backup Manager")
                            Spacer()
                            if backupValid {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Button() {
                        revert()
                    } label: {
                        Text("Revert MobileGestalt")
                            .foregroundColor(.red)
                    }
                    .disabled(backupValid != true)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Only use revert when you're experiencing issues or when your MobileGestalt is invalid.")
                }
                
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/jurre111.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Jurre")
                            .font(.headline)
                        
                        Text("The entire EditorView.")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/jurre111"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .navigationTitle("MobileGestalt")
            .alert("Status", isPresented: .constant(status != nil)) {
                Button("OK") { status = nil }
            } message: {
                Text(status ?? "")
            }
            .alert("Done", isPresented: .constant(alert != nil)) {
                Button("Cancel") { alert = nil }
                Button("Respring") {
                    alert = nil
                    mgr.respring()
                }
            } message: {
                Text(alert ?? "uhh...")
            }
            .alert(firstLoad ? "Welcome" : "No Backup Found", isPresented: .constant(backupFound == false)) {
                Button("Load from system") {
                    if valid {
                        do {
                            try fm.copyItem(at: URL(fileURLWithPath: path), to: ogmgurl)
                            if !(try fm.contentsOfDirectory(atPath: "/var/mobile")).contains(".lara") {
                                try fm.createDirectory(atPath: "/var/mobile/.lara", withIntermediateDirectories: true)
                            }
                            try fm.copyItem(at: URL(fileURLWithPath: path), to: secondBackupURL)
                            backupFound = true
                            // we can just set backupValid to true as the original mbg is already checked in init() which was just ran
                            backupValid = true
                            mgr.logmsg("(mbg) Loading backups from system...\n(mbg) success!")
                            status = "Successfully backed up MobileGestalt from system! It's highly recommended to create an ONLINE BACKUP aswell. To do so, go to lara's documents folder and save ogmobilegestalt.plist somewhere safe in the cloud."
                        } catch {
                            backupFound = true
                            mgr.logmsg("(mbg) Loading backups from system...\n(mbg) failed: \(error)")
                            status = "Failed to load backup from system: \(error). Reopen the page to retry"
                        }
                    } else {

                    }
                }
                Button("Load from files") {
                    mgr.logmsg("(mbg) Uploading backup from files...")
                    showimporter = true
                }
            } message: {
                if !firstLoad {
                    Text("In both the application documents and /var/mobile/.lara no backup of your MobileGestalt was found. You have to load a new one to use MobileGestalt tweaks safely. Do you want to load a new backup from the system or from your own backup file? Loading a backup from the system will backup the current MobileGestalt as-is, which does NOT necessarily mean it is your original MobileGestalt file. If you know your current MobileGestalt is not the true original file, please open your true original MobileGestalt from files.\n\nIf you don't understand this popup, load a backup from files if you have one or contact support in the lara discord server.")
                } else {
                    Text("Welcome! To ensure safe usage of the MobileGestalt editing feature, backups are auto-saved. Because it's your first time using MobileGestalt tweaks in lara, you don't have a backup saved at the expected location yet. Lara can automatically load the current MobileGestalt file from the system. If you're sure that your current MobileGestalt is the true original or want to make a backup of it in this state, click load from system.\n\nIf your current MobileGestalt is not the original, upload the true original from files if you have it. If you don't have the original anywhere, ping @jurre6835 in the lara discord server.")
                }
            }
            .fileImporter(
                isPresented: $showimporter,
                allowedContentTypes: [.propertyList],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let importurl = urls.first {
                    do {
                        let uploaded = try NSMutableDictionary(contentsOf: importurl, error: ())
                        let validcheck = validate(uploaded, file: importurl)
                        mgr.logmsg("(mbg) Loading uploaded backup...\n(mbg) Validating loaded backup...\n(mbg) \(validcheck.message)")
                        if validcheck.ok {
                            if !(try fm.contentsOfDirectory(atPath: "/var/mobile")).contains(".lara") {
                                try fm.createDirectory(atPath: "/var/mobile/.lara", withIntermediateDirectories: true)
                            }
                            for backup in [ogmgurl, secondBackupURL] {
                                if fm.fileExists(atPath: backup.path) {
                                    try fm.removeItem(at: backup)
                                }
                                try fm.copyItem(at: importurl, to: backup)
                            }
                            backupFound = true
                            backupValid = true
                            status = "Succes! Loaded and verified imported backup!"
                            mgr.logmsg("(mbg) Successfully loaded imported backup!")
                        } else {
                            backupFound = true
                            status = "Loaded backup is invalid: \(validcheck.message). Retry or try a different backup by clicking \"Load from files\" in Backup Manager."
                        }
                    } catch {
                        backupFound = true
                        mgr.logmsg("(mbg) Loading backups from system failed: \(error)")
                        status = "Failed to load backup from file: \(error). Retry or try a different backup by clicking \"Load from files\" in Backup Manager."
                    }
                }
            }
            .onAppear {
                if firstMGLoad {
                    firstMGLoad = false
                } else {
                    firstLoad = false
                }
                load()
                checkBackups()
                mgr.logmsg("(mbg) ogsubtype: \(ogSubType); current subtype: \(selectedSubType)")
            }
        }
    }
    
    private func validate(_ dict: NSMutableDictionary, file: URL? = nil) -> (ok: Bool, message: String) {
        // only way to get device model and iOS build
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let deviceModel = String(cString: machine)
        size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        let iosBuild = String(cString: build)

        let data: Data
        do {
            if let fileURL = file {
                data = try Data(contentsOf: fileURL)
            } else {
                data = try PropertyListSerialization.data(
                    fromPropertyList: dict,
                    format: .binary,
                    options: 0
                )
            }
            if data.count < 5000 {
                return (false, "file too small (\(data.count) bytes)")
            }
            guard let cacheExtra = dict["CacheExtra"] as? NSMutableDictionary else { return (false, "missing CacheExtra (!?)") }
            if let model = cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String,
                let build = cacheExtra["mZfUC7qo4pURNhyMHZ62RQ"] as? String {
                return (!cacheExtra.allKeys.isEmpty && model == deviceModel && build == iosBuild, "\(cacheExtra.allKeys.isEmpty ? "empty CacheExtra, " : "Cachextra exists, ")\(model != deviceModel ? "device model key doesn't match device, " : "device model key matches device, ")\(build != iosBuild ? "iOS version key doesnt match device's" : "iOS version key matches device's")")
            } else {
                return (false, "missing critical keys")
            }
        } catch {
            return(false, "error while validating MobileGestalt: \(error)")
        }
    }

    private func load() {
        do {
            let dict = try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ())
            let result = validate(dict)
            valid = result.ok
            if valid {
                mgr.logmsg("\n(mbg) Loading MobileGestalt from system...\n(mbg) success!")
                mg = dict
                guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary, let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
                    status = "Failed to get dictionaries from MobileGestalt. Reopen the page to try again."
                    return
                }
                mgr.logmsg("(mbg) Loaded CacheExtra")
                guard let subType = oPeik["ArtworkDeviceSubType"] as? Int else {
                    status = "Failed to get SubType from MobileGestalt. Reopen the page to try again."
                    return
                }
                mgr.logmsg("(mbg) Loaded ArtWorkDeviceSubType")
                selectedSubType = subType
                // This only happens on the first load
                if ogSubType == -1 {
                    ogSubType = subType
                }
            } else {
                mgr.logmsg("\n(mbg) Loading MobileGestalt from system...\n(mbg) invalid: \(result.message)")
                status = "MobileGestalt is not valid: \(result.message)\nClick reload from plist or contact support in the lara discord server."
            }
        } catch {
            mgr.logmsg("\n(mbg) Loading MobileGestalt from system...\n(mbg) failed: \(error)")
            status = "Failed to load mobilegestalt: \(error). Reopen the page to try again."
        }
    }

    private func checkBackups() {
        var result = findBackups()
        mgr.logmsg("(mbg) Looking for backups...\n(mbg) \(result.message)")
        backupFound = result.ok
        if result.ok {
            result = validateBackups()
            mgr.logmsg("(mbg) Validating backups...\n(mbg) \(result.message)")
            backupValid = result.ok
            if !result.ok {
                status = "Validating backups...\n\n\(result.message)"
            }
        } else {
            if backupFound != false {
                status = "Finding backups...\n\n\(result.message)"
            }
        }
    }

    private func findBackups() -> (ok: Bool, message: String) {
        do {
            if !fm.fileExists(atPath: ogmgurl.path) {
                if !fm.fileExists(atPath: secondBackupURL.path) {
                    backupFound = false
                    return (false, "no backups found")
                } else {
                    try fm.copyItem(at: secondBackupURL, to: ogmgurl)
                    chmod(ogmgurl.path, 0o644)
                }
            }
            if !fm.fileExists(atPath: secondBackupURL.path) {
                if !(try fm.contentsOfDirectory(atPath: "/var/mobile")).contains(".lara") {
                    try fm.createDirectory(atPath: "/var/mobile/.lara", withIntermediateDirectories: true)
                }
                try fm.copyItem(at: ogmgurl, to: secondBackupURL)
                chmod(secondBackupURL.path, 0o644)
            }
            return (true, "backups found!")
        } catch {
            return (false, "failed to check for backups: \(error)\nReopen the page or contact support.") 
        }
    }

    private func validateBackups() -> (ok: Bool, message: String) {
        var backups: [URL: NSMutableDictionary] = [ogmgurl: [:], secondBackupURL: [:]]
        do {
            var results = (ok: true, message: "")
            for backupURL in backups.keys {
                if let backupDict = try NSMutableDictionary(contentsOf: backupURL) {
                    backups[backupURL] = backupDict
                    let result = validate(backupDict, file: backupURL)
                    guard result.ok else {
                        results.ok = false
                        results.message = results.message + "backup at path \(backupURL.path) is invalid:\n\n\(result.message)\n\n"
                    }
                } else {
                    results.ok = false
                    results.message = results.message + "backup at path \(backupURL.path) contains invalid plist."
                }
            }
            if !results.ok {
                results.message = results.message + "Open Backup Manager and open your original backup from files if you have it. Else contact support in the lara discord server"
            }
            if backups[ogmgurl] != backups[secondBackupURL] {
                return (false, "backups don't match. If you've modified \(ogmgurl.path) or \(secondBackupURL.path), open Backup Manager and open your original backup from files. Else, contact support.")
            }
        } catch {
            return (false, "failed to validate backup: \(error)\nReopen the page or contact support.")
        }
        return (true, "backups are valid!")
    }

    private func apply() {
        do {
            if selectedSubType != -1 {
                guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary, let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
                    status = "Failed to get dictionaries from MobileGestalt."
                    return
                }
                oPeik["ArtworkDeviceSubType"] = selectedSubType
            } else {
                status = "Selected SubType is -1? Reload the page."
                return
            }
            let data = try PropertyListSerialization.data(
                fromPropertyList: mg,
                format: .binary,
                options: 0
            )
            
            let result = laramgr.shared.lara_overwritefile(
                target: path,
                data: data
            )
            
            if result.ok {
                mgr.logmsg("overwrote MobileGestalt at \(path)")
                alert = "Applied modified mobilegestalt, respring to see changes."
            } else {
                status = "overwrite failed: \(result.message)"
            }
            
        } catch {
            status = "serialization failed: \(error.localizedDescription)"
        }
    }

    private func revert() {
        do {
            var result = findBackups()
            if result.ok {
                result = validateBackups()
                backupValid = result.ok
                if result.ok {
                    result = laramgr.shared.lara_overwritefile(
                        target: path,
                        source: ogmgurl.path
                    )
                    if result.ok {
                        alert = "Reverted MobileGestalt from backup, respring to see changes."
                    } else {
                        status = "Overwriting \(path) failed: \(result.message). Reopen the page or contact support"
                    }
                } else {
                    status = "Validating backups...\n\n\(result.message)"
                }
            } else {
                status = "Finding backups...\n\n\(result.message)"
            }
        } catch {
            status = "Reverting failed: \(error.localizedDescription). Reopen the page or contact support."
        }
    }

    private func bindingForTrollPad() -> Binding<Bool> {
        // We're going to overwrite DeviceClassNumber but we can't do it via CacheExtra, so we need to do it via CacheData instead
        guard let cacheData = mg["CacheData"] as? NSMutableData,
              let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        let valueOffset = FindCacheDataOffset("mtrAoWJ3gsq+I90ZnQ0vQw")
        //print("Read value from \(cacheData.mutableBytes.load(fromByteOffset: valueOffset, as: Int.self))")
        
        let keys = [
            "uKc7FPnEO++lVhHWHFlGbQ", // ipad
            "mG0AnH/Vy1veoqoLRAIgTA", // MedusaFloatingLiveAppCapability
            "UCG5MkVahJxG1YULbbd5Bg", // MedusaOverlayAppCapability
            "ZYqko/XM5zD3XBfN5RmaXA", // MedusaPinnedAppCapability
            "nVh/gwNpy7Jv1NOk00CMrw", // MedusaPIPCapability,
            "qeaj75wk3HF4DwQ8qbIi7g", // DeviceSupportsEnhancedMultitasking
        ]
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? Int? {
                    return value == 1
                }
                return false
            },
            set: { enabled in
                if enabled {
                    status = "Become iPadOS is a risky feature so please take note of the following:\n\n1. iOS Only apps, like WhatsApp, can lose data. It's recommended to offload these apps.\n2. The homescreen layout can get fucked if you have empty space.\n3. If you have an alphabetical password, it's very hard to get into your phone after locking.\n4. Any option with Dock under Stage Manager should NOT be modified.\n\n Only continue if you're okay with this. Else click reload from plist"
                }
                cacheData.mutableBytes.storeBytes(of: enabled ? 3 : 1, toByteOffset: valueOffset, as: Int.self)
                for key in keys {
                    if enabled {
                        cacheExtra[key] = 1
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
                
                valid = validate(mg).ok
            }
        )
    }

    private func mgkeybinding<T: Equatable>(_ keys: [String], type: T.Type = Int.self, default: T? = 0, enable: T? = 1) -> Binding<Bool> {
        guard let cachextra = mg["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        
        return Binding(
            get: {
                if let value = cachextra[keys.first!] as? T?, let enable {
                    return value == enable
                }
                return false
            },
            set: { enabled in
                for key in keys {
                    if enabled {
                        cachextra[key] = enable
                    } else {
                        cachextra.removeObject(forKey: key)
                    }
                }
                
                valid = validate(mg).ok
            }
        )
    }

    private func requiresVersion(_ major : Int, _ minor: Int = 0, _ patch: Int = 0) -> Bool {
        // XXYYZZ: major XX, minor YY, patch ZZ
        let requiredVersion = major*10000 + minor*100 + patch
        let currentVersion = os.majorVersion*10000 + os.minorVersion*100 + os.patchVersion
        return currentVersion < requiredVersion
    }
}
