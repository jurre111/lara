//
//  FontPicker.swift
//  lara
//
//  Created by ruter on 27.03.26.
//

import SwiftUI
import Darwin

struct AppsView: View {
    @ObservedObject var mgr: laramgr
    @AppStorage("selectedmethod") private var selectedmethod: method = .vfs
    @State private var scannedapps: [scannedapp] = []
    @State private var allApps: [SBApp] = []
    @State private var iconcache: [String: UIImage] = [:]
    @State private var isLoadingApps = false

    struct scannedapp: Identifiable, Hashable {
        let id: String
        let name: String
        let bundleid: String
        let bundlepath: String
        let hasmobileprov: Bool
        let notbypassed: Bool
    }
    
    private func isbypassed(bundlepath: String) -> Bool {
        let key = "com.apple.installd.validatedByFreeProfile"
        var value: UInt8 = 0
        errno = 0
        let size = getxattr(bundlepath, key, &value, 1, 0, 0)
        guard size == 1 else { return false }
        return value != 0
    }
    
    private func sbx3apbypass() {
        guard mgr.sbxready else {
            mgr.logmsg("(sbx) sandbox escape not ready")
            return
        }

        let fm = FileManager.default
        let roots = ["/private/var/containers/Bundle/Application", "/var/containers/Bundle/Application"]
        var seen: Set<String> = []
        let stagingRoot = NSTemporaryDirectory() + "sbx_copy_test"

        do {
            if fm.fileExists(atPath: stagingRoot) {
                try fm.removeItem(atPath: stagingRoot)
            }
            try fm.createDirectory(atPath: stagingRoot, withIntermediateDirectories: true)
        } catch {
            mgr.logmsg("(sbx) failed to prepare staging dir: \(error.localizedDescription)")
            return
        }

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for uuid in entries {
                let dir = root + "/" + uuid
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { continue }
                guard let apps = try? fm.contentsOfDirectory(atPath: dir) else { continue }

                for app in apps where app.hasSuffix(".app") {
                    let bundlepath = dir + "/" + app
                    let normalized = bundlepath.hasPrefix("/private/") ? String(bundlepath.dropFirst(8)) : bundlepath
                    if seen.contains(normalized) { continue }
                    seen.insert(normalized)

                    let mp = bundlepath + "/embedded.mobileprovision"
                    if access(mp, F_OK) != 0 { continue }

                    let stagedPath = stagingRoot + "/" + app

                    do {
                        if fm.fileExists(atPath: stagedPath) {
                            try fm.removeItem(atPath: stagedPath)
                        }

                        mgr.logmsg("(sbx) copying \(bundlepath) -> \(stagedPath)")
                        try fm.copyItem(atPath: bundlepath, toPath: stagedPath)
                        mgr.logmsg("(sbx) copy success \(stagedPath)")
                    } catch {
                        mgr.logmsg("(sbx) copy failed \(bundlepath): \(error.localizedDescription)")
                        continue
                    }

                    let testKey = "com.apple.installd.validatedByFreeProfile"
                    var value: [UInt8] = [1, 2, 3]
                    errno = 0
                    let rc = setxattr(stagedPath, testKey, &value, value.count, 0, 0)
                    if rc == 0 {
                        mgr.logmsg("(sbx) set test xattr on staged copy: \(stagedPath)")
                    } else {
                        let code = errno
                        let err = String(cString: strerror(code))
                        mgr.logmsg("(sbx) failed to set test xattr on staged copy \(stagedPath) | errno=\(code) | \(err)")
                    }

                    errno = 0
                    let size = getxattr(stagedPath, testKey, nil, 0, 0, 0)
                    if size >= 0 {
                        mgr.logmsg("(sbx) verified test xattr exists on staged copy: \(stagedPath) size=\(size)")
                    } else {
                        let code = errno
                        let err = String(cString: strerror(code))
                        mgr.logmsg("(sbx) failed to verify test xattr on staged copy \(stagedPath) | errno=\(code) | \(err)")
                    }

                    return
                }
            }
        }

        mgr.logmsg("(sbx) no eligible app found for copy test")
    }

    private func scanappssbx() {
        guard mgr.sbxready else {
            scannedapps = []
            iconcache = [:]
            return
        }

        let fm = FileManager.default
        let roots = ["/private/var/containers/Bundle/Application", "/var/containers/Bundle/Application"]
        var results: [scannedapp] = []
        var scanned = 0
        var withProvision = 0
        var cache: [String: UIImage] = [:]
        var seen: Set<String> = []

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for uuid in entries {
                let dir = root + "/" + uuid
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else { continue }
                guard let apps = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for app in apps where app.hasSuffix(".app") {
                    scanned += 1
                    let bundlepath = dir + "/" + app
                    let normalizedPath = bundlepath.hasPrefix("/private/") ? String(bundlepath.dropFirst(8)) : bundlepath
                    if seen.contains(normalizedPath) { continue }
                    let infoPath = bundlepath + "/Info.plist"
                    let info = NSDictionary(contentsOfFile: infoPath) as? [String: Any]
                    let name = (info?["CFBundleDisplayName"] as? String)
                        ?? (info?["CFBundleName"] as? String)
                        ?? app
                    let bundleid = (info?["CFBundleIdentifier"] as? String) ?? "unknown"
                    let mp = bundlepath + "/embedded.mobileprovision"
                    let hasMP = access(mp, F_OK) == 0
                    if !hasMP { continue }

                    let validated = isbypassed(bundlepath: bundlepath)
                    if !validated { continue }

                    seen.insert(normalizedPath)
                    withProvision += 1

                    if let icon = loadappicon(bundlepath: bundlepath) {
                        cache[bundlepath] = icon
                    }

                    results.append(scannedapp(
                        id: bundlepath,
                        name: name,
                        bundleid: bundleid,
                        bundlepath: bundlepath,
                        hasmobileprov: hasMP,
                        notbypassed: validated
                    ))
                }
            }
        }

        results.sort { $0.name.lowercased() < $1.name.lowercased() }
        scannedapps = results
        iconcache = cache
    }
    
    private func loadAllApps() {
        isLoadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let apps = try ApplicationManager.getApps()
                DispatchQueue.main.async {
                    allApps = apps
                    isLoadingApps = false
                }
            } catch {
                mgr.logmsg("Failed to load apps: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoadingApps = false
                }
            }
        }
    }

    private func loadappicon(bundlepath: String) -> UIImage? {
        guard let bundle = Bundle(path: bundlepath) else { return nil }
        if let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            for name in files.reversed() {
                if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                    return image
                }
            }
        }
        if let name = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }
        return nil
    }
    
    var body: some View {
        List {
            Section {
                if isLoadingApps {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if allApps.isEmpty {
                    Text("No apps found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(allApps) { app in
                        HStack(spacing: 12) {
                            if let icon = app.icon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "app")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name)
                                    .font(.headline)
                                
                                Text(app.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    if app.isSystem {
                                        Label("System", systemImage: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("User", systemImage: "person")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if app.hiddenFromSpringboard {
                                        Label("Hidden", systemImage: "eye.slash")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("v\(app.version)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("All Applications (\(allApps.count))")
            }
            
            Section {
                if scannedapps.isEmpty {
                    Text("No bypassed apps found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(scannedapps) { app in
                        HStack(spacing: 12) {
                            if let icon = iconcache[app.bundlepath] {
                                Image(uiImage: icon)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image("unknown")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.headline)
                                
                                Text(app.bundleid)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Sideloaded Apps")
            }
            
            Section {
                Button {
                    sbx3apbypass()
                } label: {
                    Text("Bypass 3 App Limit")
                }
            } footer: {
                Text("Needs to be reapplied everytime you sideload a new app.")
            }
        }
        .navigationTitle("Applications")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        loadAllApps()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Button {
                        scanappssbx()
                    } label: {
                        Image(systemName: "checkmark.square")
                    }
                }
            }
        }
        .onAppear {
            scanappssbx()
            loadAllApps()
        }
    }
}

