//
//  EditorView.swift
//  lara
//
//  Created by ruter on 27.03.26.
//

// Most of the code is from Duy's SparseBox

import SwiftUI

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    
    private let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let origmgurl: URL

    @State private var mobileGestalt: NSMutableDictionary
    @State private var status: String?
    @State private var respringAlert: String?


    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        origmgurl = docs.appendingPathComponent("OriginalMobileGestalt.plist")
        let sysurl = URL(fileURLWithPath: path)
        do {
            if !FileManager.default.fileExists(atPath: origmgurl.path) {
                try FileManager.default.copyItem(at: sysurl, to: origmgurl)
            }
            chmod(origmgurl.path, 0o644)
            
            _mobileGestalt = State(initialValue: try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ()))
        } catch {
            _mobileGestalt = State(initialValue: [:])
            _status = State(initialValue: "Failed to copy MobileGestalt: \(error)")
        }

    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Action Button (iOS 17+)", isOn: bindingForMGKeys(["cT44WE1EohiwRzhsZ8xEsw"]))
                    Toggle("Allow installing iPadOS apps", isOn: bindingForMGKeys(["9MZ5AdH43csAUajl/dU+IQ"], type: [Int].self, defaultValue: [1], enableValue: [1, 2]))
                    Toggle("Always on Display (18.0+)", isOn: bindingForMGKeys(["j8/Omm6s1lsmTDFsXjsBfA", "2OOJf1VhaM7NxfRok3HbWQ"]))
                    // Toggle("Apple Intelligence", isOn: bindingForAppleIntelligence())
                    //    .disabled(requiresVersion(18))
                    Toggle("Apple Pencil", isOn: bindingForMGKeys(["yhHcB0iH0d1XzPO/CFd3ow"]))
                    Toggle("Boot chime", isOn: bindingForMGKeys(["QHxt+hGLaBPbQJbXiUJX3w"]))
                    Toggle("Camera button (18.0rc+)", isOn: bindingForMGKeys(["CwvKxM2cEogD3p+HYgaW0Q", "oOV1jhJbdV3AddkcCg0AEA"]))
                    Toggle("Charge limit (iOS 17+)", isOn: bindingForMGKeys(["37NVydb//GP/GrhuTN+exg"]))
                    Toggle("Crash Detection (might not work)", isOn: bindingForMGKeys(["HCzWusHQwZDea6nNhaKndw"]))
                    Toggle("Dynamic Island (17.4+, might not work)", isOn: bindingForMGKeys(["YlEtTtHlNesRBMal1CqRaA"]))
                    // Toggle("Disable region restrictions", isOn: bindingForRegionRestriction())
                    Toggle("Internal Storage info", isOn: bindingForMGKeys(["LBJfwOEzExRxzlAnSuI7eg"]))
                    // Toggle("Internal stuff", isOn: bindingForInternalStuff())
                    Toggle("Security Research Device", isOn: bindingForMGKeys(["XYlJKKkj2hztRP1NWWnhlw"]))
                    Toggle("Metal HUD for all apps", isOn: bindingForMGKeys(["EqrsVvjcYDdxHBiQmGhAWw"]))
                    Toggle("Stage Manager (iPad Only?)", isOn: bindingForMGKeys(["qeaj75wk3HF4DwQ8qbIi7g"]))
                } header: {
                    Text("MobileGestalt")
                } footer: {
                    Text("Note: some tweaks may not work or cause instability.\nWARNING: Never enable features your device doesn't support.")
                }
                Section {
                    Button() {
                        apply_mg()
                    } label: {
                        Text("Apply Modified MobileGestalt")
                    }
                    Button() {
                        revert_mg()
                    } label: {
                        Text("Revert MobileGestalt")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Apply")
                } footer: {
                    Text("Use at your own risk.")
                }
            }
            .navigationTitle("MobileGestalt")
            .alert("Status", isPresented: .constant(status != nil)) {
                Button("OK") { status = nil }
            } message: {
                Text(status ?? "")
            }
            .alert("Done", isPresented: .constant(respringAlert != nil)) {
                Button("Cancel") { respringAlert = nil }
                Button("Respring") { mgr.respring() }
            } message: {
                Text(respringAlert ?? "")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        do {
            mobileGestalt = try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ())
        } catch {
            status = "Failed to load mobilegestalt"
        }
    }


    private func apply_mg() {
        let fm = FileManager.default
        do {
            try mobileGestalt.write(to: URL(fileURLWithPath: path))
            mgr.logmsg("wrote custom mbgestalt to \(path)")
            respringAlert = "Applied modified mobilegestalt, respring to see changes"
            return
        } catch {
            status = "failed to write plist: \(error.localizedDescription)"
            return
        }
    }

    private func revert_mg() {
        let fm = FileManager.default
        if fm.fileExists(atPath: origmgurl.path) {
            do {
                let data = try Data(contentsOf: origmgurl)
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                mgr.logmsg("reverted MobileGestalt plist")
                mobileGestalt = try NSMutableDictionary(contentsOf: URL(fileURLWithPath: path), error: ())
                respringAlert = "Reverted MobileGestalt plist, respring to see changes"
            } catch {
                status = "Failed to replace modified plist with original: \(error.localizedDescription)"
                return
            }
        } else {
            status = "Failed to revert mobilegestalt: \(origmgurl.absoluteString) was not found"
        }
    }
    private func bindingForMGKeys<T: Equatable>(_ keys: [String], type: T.Type = Int.self, defaultValue: T? = 0, enableValue: T? = 1) -> Binding<Bool> {
        guard let cacheExtra = mobileGestalt["CacheExtra"] as? NSMutableDictionary else {
            return State(initialValue: false).projectedValue
        }
        return Binding(
            get: {
                if let value = cacheExtra[keys.first!] as? T?, let enableValue {
                    return value == enableValue
                }
                return false
            },
            set: { enabled in
                for key in keys {
                    if enabled {
                        cacheExtra[key] = enableValue
                    } else {
                        // just remove the key as it will be pulled from device tree if missing
                        cacheExtra.removeObject(forKey: key)
                    }
                }
            }
        )
    }
}
