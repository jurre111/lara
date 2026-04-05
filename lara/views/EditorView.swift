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
    private let modurl: URL

    @State private var mgXML: String = ""
    @State private var status: String?
    @AppStorage("currentSubType") private var currentSubType: Int = -1
    

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let orimg = docs.appendingPathComponent("OriginalMobileGestalt.plist")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView {
                        Text(mgXML)
                            .font(.system(size: 13, design: .monospaced))
                            .lineSpacing(1)
                            .frame(height: 250)
                            .truncationMode(.tail)
                    }
                    
                    NavigationLink {
                        
                    } label: {
                        Text("View")
                    }
                } header: {
                    Text("com.apple.MobileGestalt.plist")
                }

                Section {
                    HStack {
                        Text("Current SubType:")
                        Spacer()
                        Text(currentSubType != -1 ? String(currentSubType.wrappedValue) : "Error")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Button() {
                        // enable_dynisland()
                    } label: {
                        Text("Enable Dynamic Island")
                    }
                } header: {
                    Text("Modify")
                }
            }
            .navigationTitle("MobileGestalt")
            .alert("Status", isPresented: .constant(status != nil)) {
                Button("OK") { status = nil }
            } message: {
                Text(status ?? "")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let fm = FileManager.default
        let sysURL = URL(fileURLWithPath: path)

        if !fm.fileExists(atPath: modurl.path) {
            do {
                try fm.copyItem(at: sysURL, to: modurl)
            } catch {
                status = "failed to copy plist: \(error.localizedDescription)"
                return
            }
        }

        do {
            let data = try Data(contentsOf: modurl)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            let xmlData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            mgXML = String(data: xmlData, encoding: .utf8) ?? "failed to encode XML"

            currentSubType = getPlistIntValue(plistPath: orimg, key: "ArtworkDeviceSubType")
        } catch {
            status = "failed to load plist: \(error.localizedDescription)"
        }
    }
    // copied from Cowabunga
    func getPlistIntValue(plistPath: URL, key: String) -> Int {
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
}