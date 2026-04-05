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

    @State private var mgXML: String = ""
    @State private var status: String?
    @State private var respringAlert: String?
    @State private var customSubType: Int = 2796
    @State private var customSubTypeEnabled: Bool = false
    @AppStorage("currentSubType") private var currentSubType: Int = -1
    

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        mgurl = docs.appendingPathComponent("OriginalMobileGestalt.plist")
        modmgurl = docs.appendingPathComponent("ModifiedMobileGestalt.plist")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // HStack {
                    //     Text("Current SubType:")
                    //     Spacer()
                    //     if currentSubType != -1 {
                    //         Text(String(currentSubType))
                    //     }
                    //     Button {
                    //         load()
                    //     } label: {
                    //         Image(systemName: "arrow.clockwise")
                    //     }
                    // }
                    // Toggle("Custom SubType", isOn: $customSubTypeEnabled)
                    // if customSubTypeEnabled {
                    //     TextField("SubType eg. 2796", value: $customSubType, formatter: NumberFormatter())
                    //         .keyboardType(.numberPad)
                    //         .textFieldStyle(.roundedBorder)
                    // }
                    Button() {
                        applySubType()
                    } {
                        Text("customSubTypeEnabled" ? "Replace SubType" : "Enable Dynamic Island")
                    }
                } header: {
                    Text("ArtworkDeviceSubType")
                }
                
                
                Section {
                    Button() {
                        apply_mg()
                    } label: {
                        Text("Apply")
                    }
                    Button() {
                        revert_mg()
                    } label: {
                        Text("Revert")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Apply")
                } footer: {
                    Text("Note: you can use file manager to edit the modified plist to modify more keys.")
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
        currentSubType = getPlistIntValue(plistPath: sysURL, key: "ArtworkDeviceSubType")
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
                respringAlert = "reverted MobileGestalt plist, respring to see changes"
            } catch {
                status = "failed to replace modified plist with original: \(error.localizedDescription)"
                return
            }
        }
    }
}