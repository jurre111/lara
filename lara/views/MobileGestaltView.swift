import SwiftUI

struct MobileGestaltView: View {
    @StateObject private var manager = MobileGestaltManager()
    @State private var showEditSheet = false
    @State private var editingKey: String = ""
    @State private var editingValue: String = ""
    @State private var isEditingExisting = false
    @State private var showApplyConfirm = false
    @State private var showRestoreConfirm = false
    @State private var showRespringPrompt = false
    @State private var statusMessage: String? = nil
    @State private var showStatusAlert = false
    @State private var verificationResult: String? = nil

    var body: some View {
        VStack {
            HStack {
                Text("MobileGestalt")
                    .font(.title2)
                    .padding(.leading)
                Spacer()
                Button("Refresh") {
                    manager.refresh()
                }
                .padding(.trailing)
                Button("Add") {
                    editingKey = ""
                    editingValue = ""
                    isEditingExisting = false
                    showEditSheet = true
                }
                .padding(.trailing)
            }

            List(manager.entries) { entry in
                VStack(alignment: .leading) {
                    Text(entry.key).font(.headline)
                    Text(entry.value).font(.subheadline)
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button("Edit") {
                        editingKey = entry.key
                        editingValue = manager.getValue(for: entry.key) ?? ""
                        isEditingExisting = true
                        showEditSheet = true
                    }
                    Button("Remove Override") {
                        manager.removeOverride(key: entry.key)
                    }
                }
            }
            Section("Persistence") {
                HStack {
                    Button("Save Overrides to KFS") {
                        let ok = manager.saveOverridesToKFS()
                        manager.refresh()
                        statusMessage = ok ? "Saved overrides to KFS." : "Failed to save overrides to KFS."
                        showStatusAlert = true
                    }
                    Spacer()
                    Button("Load Overrides from KFS") {
                        let ok = manager.loadOverridesFromKFS()
                        manager.refresh()
                        statusMessage = ok ? "Loaded overrides from KFS." : "Failed to load overrides from KFS."
                        showStatusAlert = true
                    }
                }

                HStack {
                    Button("Apply Overrides to System Cache") {
                        showApplyConfirm = true
                    }
                    Spacer()
                    Button("Restore Backup") {
                        showRestoreConfirm = true
                    }
                }
            }
        }
        .onAppear { manager.refresh() }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("Key") {
                        TextField("Key", text: $editingKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Section("Value") {
                        TextField("Value", text: $editingValue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .navigationTitle(isEditingExisting ? "Edit Override" : "Add Override")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { showEditSheet = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            guard !editingKey.isEmpty else { return }
                            manager.setOverride(key: editingKey, value: editingValue)
                            showEditSheet = false
                        }
                    }
                }
            }
        }
        .alert("Apply Overrides?", isPresented: $showApplyConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Apply", role: .destructive) {
                let ok = manager.applyOverridesToSystemCache()
                manager.refresh()
                if ok {
                    statusMessage = "Applied overrides to system cache."
                    // verify a representative key (Dynamic Island obfuscated key from EditorView)
                    let dynKey = "YlEtTtHlNesRBMal1CqRaA"
                    if let verified = manager.verifyKeyInSystemCache(key: dynKey) {
                        verificationResult = verified ? "Verified: Dynamic Island key present in system cache." : "Verification: key not found in system cache."
                    } else {
                        verificationResult = "Verification unavailable (KFS read failed)."
                    }
                    showRespringPrompt = true
                    showStatusAlert = true
                } else {
                    statusMessage = "Failed to apply overrides."
                    showStatusAlert = true
                }
            }
        } message: {
            Text("This will backup the current MobileGestalt cache and overwrite it. Proceed?")
        }

        .alert("Reload now?", isPresented: $showRespringPrompt) {
            Button("Later", role: .cancel) { showRespringPrompt = false }
            Button("Respring", role: .destructive) {
                laramgr.shared.respring()
                statusMessage = "Respring requested; expect UI restart."
                showStatusAlert = true
            }
        } message: {
            Text("Respring is recommended to make MobileGestalt changes take effect immediately.")
        }

        .alert("Restore Backup?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                let ok = manager.restoreSystemCacheFromBackup()
                manager.refresh()
                statusMessage = ok ? "Restored MobileGestalt cache from backup." : "Failed to restore backup."
                showStatusAlert = true
            }
        } message: {
            Text("This will restore the previously backed up MobileGestalt cache. Proceed?")
        }

        .alert("Status", isPresented: $showStatusAlert) {
            Button("OK") { showStatusAlert = false }
        } message: {
            VStack(alignment: .leading) {
                Text(statusMessage ?? "")
                if let v = verificationResult {
                    Text(v).foregroundColor(.secondary)
                }
            }
        }
    }
}

struct MobileGestaltView_Previews: PreviewProvider {
    static var previews: some View {
        MobileGestaltView()
    }
}
