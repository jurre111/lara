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

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var mg: NSMutableDictionary
    @State private var status: String?
    @State private var alert: String?
    @State private var valid: Bool = true
    @State private var selectedSubType: Int = -1
    @State private var showimporter: Bool = false

    // backup stuff
    @State private var backupFound: Bool?
    @State private var backupValid: Bool?


    @AppStorage("ogSubType") private var ogSubType: Int = -1
    // @AppStorage("defaultMgKeys") private var defaultMgKeys: [String: Any]?
    @AppStorage("firstLoad") private var firstLoad: Bool = true

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
    let fm = FileManager.default

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        ogmgurl = docs.appendingPathComponent("ogmobilegestalt.plist")
        load()
        guard let cacheExtra = mg["CacheExtra"] as? NSMutableDictionary, let oPeik = cacheExtra["oPeik/9e8lQWMszEjbPzng"] as? NSMutableDictionary else {
            _status = State(initialValue: "Failed to get dictionaries from MobileGestalt. Reopen the page.")
            return
        }
        guard let subType = oPeik["ArtworkDeviceSubType"] as? Int else {
            _status = State(initialValue: "Failed to get SubType from MobileGestalt. Reopen the page.")
            return
        }
        _selectedSubType = State(initialValue: subType)
        // This only happens on the first load
        if ogSubType == -1 {
            ogSubType = subType
        }
        backupValid = checkBackup()

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
                    Text("Note: some tweaks may not work or cause instability.")
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
                    Text("Use at your own risk.")
                }

                Section {
                    Button() {
                        revert()
                    } label: {
                        Text("Revert MobileGestalt")
                    }
                    .disabled(backupValid != true)
                } header: {
                    Text("Revert")
                } footer: {
                    Text("Only use when you're experiencing issues or when your MobileGestalt is invalid.")
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
                    do {
                        let secondBackupURL = URL(fileURLWithPath: "/var/mobile/.lara/ogmobilegestalt.plist")
                        try fm.copyItem(at: URL(fileURLWithPath: path), to: ogmgurl)
                        try fm.copyItem(at: URL(fileURLWithPath: path), to: secondBackupURL)
                        backupFound = true
                        backupValid = checkBackup()
                        if backupValid == true {
                            status = "Successfully backed up MobileGestalt from system! Reload the page."
                        } else {
                            status = "Loaded backup is invalid. Reload the page."
                        }
                    } catch {
                        backupFound = true
                        status = "Failed to load backup from system: \(error). Reload the page"
                    }
                }
                Button("Load from files") {
                    showimporter = true
                }
            } message: {
                if !firstLoad {
                    Text("In both the application documents and /var/mobile/.lara no backup of your MobileGestalt was found. You have to load a new one. Do you want to load a new backup from the system or from your own backup file? Loading a backup from the system will backup the current MobileGestalt as-is, which does NOT necessarily mean it is your original MobileGestalt file. If you know your current MobileGestalt is not the true original file, please open your true original MobileGestalt from files.\n\nIf you don't understand this popup, load a backup from files if you have one. Else contact support.")
                } else {
                    Text("Welcome! To ensure safe usage of the MobileGestalt editing feature, backups are auto-saved. Because it's your first time using MobileGestalt tweaks in lara, you don't have a backup saved at the expected location yet. Lara can automatically load the current MobileGestalt file from the system. If you're sure that your current MobileGestalt is the true original or want to make a backup of it in this state, click load from system.\n\nIf your current MobileGestalt is not the original, upload the true original from files if you have it. If you don't have the original anywhere, ping @jurre6835 in the lara discord server.")
                }
            }
            .fileImporter(
                isPresented: $showimporter,
                allowedContentTypes: [.plist],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let importurl = urls.first {
                    do {
                        let secondBackupURL = URL(fileURLWithPath: "/var/mobile/.lara/ogmobilegestalt.plist")
                        try fm.copyItem(at: importurl, to: ogmgurl)
                        try fm.copyItem(at: importurl, to: secondBackupURL)
                        backupFound = true
                        backupValid = checkBackup()
                        if backupValid == true {
                            status = "Successfully backed up MobileGestalt from loaded file! Reload the page."
                        } else {
                            status = "Loaded backup is invalid. Reload the page."
                        }
                    } catch {
                        backupFound = true
                        status = "Failed to load backup from file: \(error). Reload the page."
                    }
                }
            }
        }
    }
    
    private func validate(_ dict: NSMutableDictionary, file: URL) -> Bool {
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

        do {
            let data = try Data(contentsOf: file)
            if data.count < 5000 {
                status = "File too small: \(data.count) bytes."
                return false
            }
            guard let cacheExtra = dict["CacheExtra"] as? NSMutableDictionary else { return false }
            if (cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String) == deviceModel && (cacheExtra["mZfUC7qo4pURNhyMHZ62RQ"] as? String) == iosBuild {
                return !cacheExtra.allKeys.isEmpty
            }
        } catch {
            status = "Failed to validate MobileGestalt: \(error). Reload the page or contact support."
        }
        return false
    }

    private func load() {
        do {
            mg = try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ())
        } catch {
            mg = [:]
            status = "Failed to load mobilegestalt: \(error). Reload the page."
        }
        valid = validate(mg, file: URL(fileURLWithPath: path))
    }

    private func checkBackup() -> Bool {
        do {
            let secondBackupURL = URL(fileURLWithPath: "/var/mobile/.lara/ogmobilegestalt.plist")
            if !fm.fileExists(atPath: ogmgurl.path) {
                if !fm.fileExists(atPath: secondBackupURL.path) {
                    backupFound = false
                    return false
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
            backupFound = true

            let backup1 = try NSDictionary(contentsOf: ogmgurl)
            let backup2 = try NSDictionary(contentsOf: secondBackupURL)
            guard validate(backup1, file: ogmgurl) else {
                status = "Backup at path \(ogmgurl.path) is invalid. Please replace it with the original backup or contact support."
                return false
            }
            guard validate(backup2, file: secondBackupURL) else {
                status = "Backup at path \(secondBackupURL.path) is invalid. Please replace it with the original backup or contact support."
                return false
            }
            if backup1 != backup2 {
                status = "Backups don't match. If you've modified \(ogmgurl.path) or \(secondBackupURL.path), please replace it with the original backup. Else, contact support."
                return false
            }
        } catch {
            status = "Failed to check backup: \(error). Reload the page or contact support."
            return false
        }
        return true
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
            status = "serialization failed: \(error.localizedDescription). Reload the page or contact support."
        }
    }

    private func revert() {
        do {
            backupValid = checkBackup()
            if !backupValid! {
                status = "Backup is invalid."
                return
            }
            try fm.replaceItem(at: URL(fileURLWithPath: path), withItemAt: ogmgurl)
            alert = "Reverted MobileGestalt from backup, respring to see changes."
            
        } catch {
            status = "serialization failed: \(error.localizedDescription). Reload the page or contact support."
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
                
                valid = validate(mg, file: URL(fileURLWithPath: path))
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
                
                valid = validate(mg, file: URL(fileURLWithPath: path))
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
