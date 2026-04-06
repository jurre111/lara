//
//  FontPicker.swift
//  lara
//
//  Created by ruter on 27.03.26.
//

import SwiftUI

struct EditorView: View {
    @ObservedObject private var mgr = laramgr.shared
    
    private let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    private let mgurl: URL
    private let modmgurl: URL

    class Tweak {
        var enabled: Bool = false
        let name: String
        let mods: [TweakMod]

        init(name: String, mods: [TweakMod]) {
            self.name = name
            self.mods = mods
        }
    }
    class TweakMod {
        let key: String
        let value: Int
        
        init(key: String, value: Int = 1) {
            self.key = key
            self.value = value
        }
    }

    @State private var mgXML: String = ""
    @State private var status: String?
    @State private var respringAlert: String?
    @State private var customSubType: Int = 2796
    @State private var customSubTypeEnabled: Bool = false
    @State private var currentSubType: Int = -1
    @State private var originalSubType: Int = -1
    enum SubType: Int, CaseIterable, Identifiable {
        case iPhone14Pro = 2556
        case iPhone14ProMax = 2796
        case iPhone16Pro = 2622
        case iPhone16ProMax = 2868

        var id: Int { self.rawValue }
        var displayName: String {
            switch self {
            case .iPhone14Pro: return "iPhone 14 Pro Dynamic Island (2556)"
            case .iPhone14ProMax: return "iPhone 14 Pro Max Dynamic Island (2796)"
            case .iPhone16Pro: return "iPhone 16 Pro Dynamic Island (2622)"
            case .iPhone16ProMax: return "iPhone 16 Pro Max Dynamic Island (2868)"
            }
        }
    }

    @State private var tweaks = [
        Tweak(name: "AOD", mods: [TweakMod(key: "2OOJf1VhaM7NxfRok3HbWQ"), TweakMod(key: "j8/Omm6s1lsmTDFsXjsBfA")]),
        Tweak(name: "Action Button", mods: [TweakMod(key: "cT44WE1EohiwRzhsZ8xEsw")])
    ]
    

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        mgurl = docs.appendingPathComponent("OriginalMobileGestalt.plist")
        modmgurl = docs.appendingPathComponent("ModifiedMobileGestalt.plist")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Gestures / Dynamic Island", selection: $currentSubType) {
                        Text("Original (\(originalSubType))").tag(originalSubType)
                        ForEach(SubType.allCases) { subtype in
                            Text(subtype.displayName).tag(subtype.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    ForEach(tweaks, id: \.name) { tweak in
                        Toggle(tweak.name, isOn: .constant(tweak.enabled))
                    }
                    Button() {
                        for tweak in tweaks {
                            applyMgTweak(mods: tweak.mods)
                        }
                    } label: {
                        Text("Apply Tweaks")
                    }
                } header: {
                    Text("Tweaks")
                }

                // Section {
                //     Toggle("Enable AOD", isOn: $AODEnabled)
                //     Button() {
                //         applyAOD()
                //     } label: {
                //         Text("Apply")
                //     }
                // } header: {
                //     Text("AOD")
                // }
                // Section {
                //     HStack {
                //         Text("Current SubType:")
                //         Spacer()
                //         if currentSubType != -1 {
                //             Text(String(currentSubType))
                //         }
                //         Button {
                //             load()
                //         } label: {
                //             Image(systemName: "arrow.clockwise")
                //         }
                //     }
                //     Toggle("Custom SubType (risky)", isOn: $customSubTypeEnabled)
                //     if customSubTypeEnabled {
                //         TextField("SubType eg. 2796", value: $customSubType, formatter: NumberFormatter())
                //             .keyboardType(.numberPad)
                //     }
                //     Button() {
                //         applySubType()
                //     } label: {
                //         Text(customSubTypeEnabled ? "Replace SubType" : "Enable Dynamic Island")
                //     }
                // } header: {
                //     Text("ArtworkDeviceSubType")
                // }
                
                
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
                    Text("Note: you can use a file manager to edit the modified plist in lara's Documents folder to modify more keys.")
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
        let fm = FileManager.default
        let sysURL = URL(fileURLWithPath: path)

        if !fm.fileExists(atPath: mgurl.path) {
            do {
                try fm.copyItem(at: sysURL, to: mgurl)
            } catch {
                status = "failed to copy plist: \(error.localizedDescription)"
                return
            }
        }
        for tweak in tweaks {
            if getPlistIntValue(plistPath: sysURL, key: tweak.mods[0].key) == tweak.mods[0].value {
                tweak.enabled = true
            }
        }
        currentSubType = getPlistIntValue(plistPath: sysURL, key: "ArtworkDeviceSubType")
        originalSubType = getPlistIntValue(plistPath: mgurl, key: "ArtworkDeviceSubType")
    }
    // copied from Cowabunga
    private func getPlistIntValue(plistPath: URL, key: String) -> Int {
        // open plist
        guard let data = try? Data(contentsOf: plistPath) else {
            print("Could not get plist data!")
            return -1
        }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            print("Could not convert plist!")
            return -1
        }
        
        func getDictValue(_ dict: [String: Any], _ key: String) -> Int {
            for (k, v) in dict {
                if k == key {
                    return dict[k] as! Int
                } else if let subDict = v as? [String: Any] {
                    let temp: Int = getDictValue(subDict, key)
                    if temp != -1 {
                        return temp
                    }
                }
            }
            // did not find key in dictionary
            return -1
        }
        
        // find the value
        return getDictValue(plist, key)
    }
    private func setPlistValueInt(plistPath: URL, key: String, value: Int) -> Bool {
        let stringsData = try! Data(contentsOf: plistPath)
        
        // open plist
        let plist = try! PropertyListSerialization.propertyList(from: stringsData, options: [], format: nil) as! [String: Any]
        func changeDictValue(_ dict: [String: Any], _ key: String, _ value: Int) -> [String: Any] {
            var newDict = dict
            for (k, v) in dict {
                if k == key {
                    newDict[k] = value
                } else if let subDict = v as? [String: Any] {
                    newDict[k] = changeDictValue(subDict, key, value)
                }
            }
            return newDict
        }
        
        // modify value
        var newPlist = plist
        newPlist = changeDictValue(newPlist, key, value)
        
        // overwrite the plist
        let newData = try! PropertyListSerialization.data(fromPropertyList: newPlist, format: .binary, options: 0)
        do {
            try newData.write(to: plistPath)
            return true
        } catch {
            return false
        }
    }

    private func applyMgTweak(mods: [TweakMod]) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: modmgurl.path) {
            do {
                try fm.copyItem(at: mgurl, to: modmgurl)
            } catch {
                status = "failed to copy plist: \(error.localizedDescription)"
                return
            }
        }
        for mod in mods {
            setPlistValueInt(plistPath: modmgurl, key: mod.key, value: mod.value)
        }
    }
    
    private func applySubType() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: modmgurl.path) {
            do {
                try fm.copyItem(at: mgurl, to: modmgurl)
            } catch {
                status = "failed to copy plist: \(error.localizedDescription)"
                return
            }
        }
        setPlistValueInt(plistPath: modmgurl, key: "ArtworkDeviceSubType", value: customSubType)
    }

    // private func applyAOD() {
    //     let fm = FileManager.default
    //     if !fm.fileExists(atPath: modmgurl.path) {
    //         do {
    //             try fm.copyItem(at: mgurl, to: modmgurl)
    //         } catch {
    //             status = "failed to copy plist: \(error.localizedDescription)"
    //             return
    //         }
    //     }
    //     setPlistValueInt(plistPath: modmgurl, key: "2OOJf1VhaM7NxfRok3HbWQ", value: AODEnabled ? 1 : 0)
    //     setPlistValueInt(plistPath: modmgurl, key: "j8/Omm6s1lsmTDFsXjsBfA", value: AODEnabled ? 1 : 0)
    // }

    private func apply_mg() {
        let fm = FileManager.default
        if fm.fileExists(atPath: modmgurl.path) {
            do {
                let data = try Data(contentsOf: modmgurl)
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                respringAlert = "Applied modified mobilegestalt, respring to see changes"
            } catch {
                status = "failed to copy plist: \(error.localizedDescription)"
                return
            }
        }
    }

    private func revert_mg() {
        let fm = FileManager.default
        if fm.fileExists(atPath: mgurl.path) {
            do {
                let data = try Data(contentsOf: mgurl)
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                mgr.logmsg("reverted MobileGestalt plist")
                respringAlert = "Reverted MobileGestalt plist, respring to see changes"
            } catch {
                status = "failed to replace modified plist with original: \(error.localizedDescription)"
                return
            }
        }
    }
}