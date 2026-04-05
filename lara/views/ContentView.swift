//
//  ContentView.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @AppStorage("showfmintabs") private var showfmintabs: Bool = true
    @Appstorage("betaFeaturesEnabled") private var betaFeaturesEnabled: Bool = false
    @ObservedObject private var mgr = laramgr.shared
    @State private var uid: uid_t = getuid()
    @State private var pid: pid_t = getpid()
    @State private var hasoffsets = haskernproc()
    @State private var showsettings = false
    @State private var selectedmethod: method = .sbx
    
    var body: some View {
        NavigationStack {
            List {
                if !hasoffsets {
                    Section("Setup") {
                        Text("Kernelcache offsets are missing. Download them in Settings.")
                            .foregroundColor(.secondary)
                        Button("Open Settings") {
                            showsettings = true
                        }
                    }
                } else {
                    Section {
                        Button {
                            mgr.run()
                        } label: {
                            if mgr.dsrunning {
                                HStack {
                                    ProgressView(value: mgr.dsprogress)
                                        .progressViewStyle(.circular)
                                        .frame(width: 18, height: 18)
                                    Text("Running...")
                                    Spacer()
                                    Text("\(Int(mgr.dsprogress * 100))%")
                                }
                            } else {
                                if mgr.dsready {
                                    HStack {
                                        Text("Ran Exploit")
                                        Spacer()
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                    }
                                } else if mgr.dsattempted && mgr.dsfailed {
                                    HStack {
                                        Text("Exploit Failed")
                                        Spacer()
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.red)
                                    }
                                } else {
                                    Text("Run Exploit")
                                }
                            }
                        }
                        .disabled(mgr.dsrunning)
                        .disabled(mgr.dsready)
                        
                        HStack {
                            Text("kernproc:")
                            Spacer()
                            Text(String(format: "0x%llx", getrootvnode()))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("rootvnode:")
                            Spacer()
                            Text(String(format: "0x%llx", getkernproc()))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        if mgr.dsready {
                            HStack {
                                Text("kernel_base:")
                                Spacer()
                                Text(String(format: "0x%llx", mgr.kernbase))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("kernel_slide:")
                                Spacer()
                                Text(String(format: "0x%llx", mgr.kernslide))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Kernel Read Write")
                    } footer: {
                        if g_isunsupported {
                            Text("Your device/installation method may not be supported.")
                        }
                    }

                    Section(selectedmethod == .vfs ? "Virtual File System" : "Sandbox Escape") {
                        if selectedmethod == .vfs {
                            Button {
                                mgr.vfsinit()
                            } label: {
                                if mgr.vfsrunning {
                                    HStack {
                                        ProgressView(value: mgr.vfsprogress)
                                            .progressViewStyle(.circular)
                                            .frame(width: 18, height: 18)
                                        Text("Initialising VFS...")
                                        Spacer()
                                        Text("\(Int(mgr.vfsprogress * 100))%")
                                    }
                                } else if !mgr.vfsready {
                                    if mgr.vfsattempted && mgr.vfsfailed {
                                        HStack {
                                            Text("VFS Init Failed")
                                            Spacer()
                                            Image(systemName: "xmark.circle")
                                                .foregroundColor(.red)
                                        }
                                    } else {
                                        Text("Initialise VFS")
                                    }
                                } else {
                                    HStack {
                                        Text("Initialised VFS")
                                        Spacer()
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .disabled(!mgr.dsready || mgr.vfsready || mgr.vfsrunning)

                            if mgr.vfsready {
                                NavigationLink("Font Overwrite") {
                                    FontPicker(mgr: mgr)
                                }

                                NavigationLink("DirtyZero (Broken)") {
                                    ZeroView(mgr: mgr)
                                }

                                if !showfmintabs {
                                    NavigationLink("File Manager") {
                                        SantanderView(startPath: "/")
                                    }
                                }
                            }
                        } else {
                            Button {
                                mgr.sbxescape()
                            } label: {
                                if mgr.sbxrunning {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .frame(width: 18, height: 18)
                                        Text("Escaping Sandbox...")
                                    }
                                } else if !mgr.sbxready {
                                    if mgr.sbxattempted && mgr.sbxfailed {
                                        HStack {
                                            Text("Sandbox Escape Failed")
                                            Spacer()
                                            Image(systemName: "xmark.circle")
                                                .foregroundColor(.red)
                                        }
                                    } else {
                                        Text("Escape Sandbox")
                                    }
                                } else {
                                    HStack {
                                        Text("Sandbox Escaped")
                                        Spacer()
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .disabled(!mgr.dsready || mgr.sbxready || mgr.sbxrunning)

                            if mgr.sbxready {
                                if !showfmintabs {
                                    NavigationLink("File Manager") {
                                        SantanderView(startPath: "/")
                                    }
                                }
                                
                                NavigationLink("3 App Bypass (Broken?)") {
                                    AppsView(mgr: mgr)
                                }
                                
                                NavigationLink("Unblacklist (Broken?)") {
                                    WhitelistView()
                                }
                                
                                if betaFeaturesEnabled {
                                    
                                    NavigationLink("Passcode Theme") {
                                        PasscodeView(mgr: mgr)
                                    }

                                    NavigationLink("MobileGestalt") {
                                        EditorView()
                                    }
                                }
                            }
                        }

                        HStack {
                            Text("UID:")

                            Spacer()

                            Text("\(uid)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)

                            Button {
                                uid = getuid()
                                print(uid)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }

                        HStack {
                            Text("PID:")

                            Spacer()

                            Text("\(pid)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)

                            Button {
                                pid = getpid()
                                print(pid)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    Section {
                        NavigationLink("Tools") {
                            ToolsView()
                        }
                        
                        if #unavailable(iOS 18.2) {
                            Button("Respring") {
                                mgr.respring()
                            }
                        }
                        
                        Button("Panic!") {
                            mgr.panic()
                        }
                        .disabled(!mgr.dsready)
                    } header: {
                        Text("Other")
                    }
                }
                
            }
            .navigationTitle("lara")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showsettings) {
            SettingsView(hasoffsets: $hasoffsets)
        }
        .onAppear {
            refreshSelectedMethod()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshSelectedMethod()
        }
    }

    private func refreshSelectedMethod() {
        if let raw = UserDefaults.standard.string(forKey: "selectedmethod"),
           let m = method(rawValue: raw) {
            selectedmethod = m
        }
    }
}
