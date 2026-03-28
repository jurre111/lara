import SwiftUI

struct ThreeAppBypassView: View {
    @ObservedObject private var mgr = laramgr.shared
    @ObservedObject private var tb = ThreeAppBypassManager.shared
    @State private var patchPath: String = "/var/mobile/Library/lara/3appbypass_patch.json"
    @State private var loadedName: String = "(none)"
    @State private var applying = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Patch file:")
                Spacer()
                Text(patchPath)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Load Patch") {
                    guard mgr.kfsready else { tb.lastError = "KFS not initialised"; return }
                    if let ps = ThreeAppBypassManager.shared.loadPatch(from: patchPath) {
                        loadedName = ps.name ?? "(unnamed)"
                        tb.lastError = nil
                        tb.status = "loaded"
                    }
                }
                .disabled(!mgr.kfsready)

                Button("Apply Patch") {
                    guard mgr.kfsready else { tb.lastError = "KFS not initialised"; return }
                    guard let ps = ThreeAppBypassManager.shared.loadPatch(from: patchPath) else { return }
                    applying = true
                    ThreeAppBypassManager.shared.apply(patch: ps)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { applying = false }
                }
                .disabled(!mgr.kfsready || applying)

                Button("Restore Backups") {
                    guard mgr.kfsready else { tb.lastError = "KFS not initialised"; return }
                    ThreeAppBypassManager.shared.restoreBackup()
                }
                .disabled(!mgr.kfsready)
            }

            HStack {
                Text("Patch loaded:")
                Spacer()
                Text(loadedName)
            }

            Divider()

            if let le = tb.lastError {
                Text("Error: \(le)")
                    .foregroundColor(.red)
            }

            HStack {
                Text("Status:")
                Spacer()
                Text(tb.status)
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()
        }
        .padding()
        .navigationTitle("3 App Bypass")
    }
}
