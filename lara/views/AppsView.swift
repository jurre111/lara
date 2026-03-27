import SwiftUI

struct AppsView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var apps: [SideloadedApp] = []
    @State private var loadError: String?
    @State private var showError = false

    var body: some View {
        List {
            if apps.isEmpty {
                Text(mgr.kfsready ? "No sideloaded apps found." : "KFS not ready.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(apps) { app in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.headline)
                        Text(app.bundleId)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text(app.bundlePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Sideloaded Apps")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reload") {
                    loadApps()
                }
            }
        }
        .alert("Failed to Load", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(loadError ?? "Unknown error")
        }
        .onAppear {
            loadApps()
        }
    }

    private func loadApps() {
        do {
            apps = try SideloadedAppEnumerator.fetchSideloadedApps(using: mgr)
            loadError = nil
        } catch {
            loadError = "\(error)"
            showError = true
            mgr.logmsg("[sideload] \(error)")
        }
    }
}

struct SideloadedApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let bundlePath: String
}

enum SideloadedAppEnumerator {
    private static let appRoot = "/var/containers/Bundle/Application"

    static func fetchSideloadedApps(using mgr: laramgr) throws -> [SideloadedApp] {
        guard mgr.kfsready else {
            mgr.logmsg("[sideload] kfs not ready")
            throw NSError(domain: "lara.apps", code: 1, userInfo: [NSLocalizedDescriptionKey: "KFS is not ready."])
        }
        guard let containerEntries = mgr.kfslistdir(path: appRoot) else {
            mgr.logmsg("[sideload] kfs listdir failed: \(appRoot)")
            throw NSError(domain: "lara.apps", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to list app containers."])
        }

        mgr.logmsg("[sideload] containers: \(containerEntries.count)")
        var results: [SideloadedApp] = []

        for container in containerEntries where container.isDir && container.name != "." && container.name != ".." {
            let containerPath = "\(appRoot)/\(container.name)"
            guard let appEntries = mgr.kfslistdir(path: containerPath) else {
                mgr.logmsg("[sideload] listdir failed: \(containerPath)")
                continue
            }

            for appEntry in appEntries where appEntry.isDir && appEntry.name.hasSuffix(".app") {
                let appBundlePath = "\(containerPath)/\(appEntry.name)"
                guard hasEmbeddedMobileProvision(in: appBundlePath, mgr: mgr) else { continue }

                let infoPath = "\(appBundlePath)/Info.plist"
                let info = readPlist(at: infoPath, mgr: mgr)
                let bundleId = info?["CFBundleIdentifier"] as? String ?? "unknown"
                let name = (info?["CFBundleDisplayName"] as? String)
                    ?? (info?["CFBundleName"] as? String)
                    ?? appEntry.name.replacingOccurrences(of: ".app", with: "")

                results.append(SideloadedApp(name: name, bundleId: bundleId, bundlePath: appBundlePath))
            }
        }

        mgr.logmsg("[sideload] matches: \(results.count)")
        return results.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static func hasEmbeddedMobileProvision(in appBundlePath: String, mgr: laramgr) -> Bool {
        guard let entries = mgr.kfslistdir(path: appBundlePath) else {
            mgr.logmsg("[sideload] listdir failed: \(appBundlePath)")
            return false
        }
        return entries.contains { $0.name == "embedded.mobileprovision" && !$0.isDir }
    }

    private static func readPlist(at path: String, mgr: laramgr) -> [String: Any]? {
        guard let data = mgr.kfsread(path: path, maxSize: 512 * 1024) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        return plist as? [String: Any]
    }
}
