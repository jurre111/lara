//
//  ContentView.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var uid: uid_t = getuid()
    @State private var pid: pid_t = getpid()
    @State private var hasoffsets = haskernproc()
    @State private var showresetalert = false
    @State private var pacSelfTestResult: Bool? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if !hasoffsets {
                    Section("Kernelcache") {
                        Button("Download Kernelcache") {
                            DispatchQueue.global(qos: .userInitiated).async {
                                let ok = dlkerncache()
                                DispatchQueue.main.async {
                                    hasoffsets = ok
                                }
                            }
                        }
                    }
                } else {
                    Section("Kernel Read Write") {
                        Button {
                            mgr.run()
                        } label: {
                            if mgr.dsrunning {
                                HStack {
                                    ProgressView()
                                    Text("Running...")
                                }
                            } else {
                                if mgr.dsready {
                                    HStack {
                                        Text("Ran Exploit")
                                        Spacer()
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
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
                    }

                    Section("Kernel File System") {
                        Button {
                            mgr.kfsinit()
                        } label: {
                            if !mgr.kfsready {
                                Text("Initialise KFS")
                            } else {
                                HStack {
                                    Text("Initialised KFS")
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .disabled(!mgr.dsready || mgr.kfsready)
                        
                        if mgr.kfsready {
                            NavigationLink("Font Overwrite") {
                                FontPicker(mgr: mgr)
                            }
                            NavigationLink("MobileGestalt Editor") {
                                MobileGestaltView()
                            }
                            NavigationLink("3 App Bypass") {
                                ThreeAppBypassView()
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
                        if #unavailable(iOS 18.2) {
                            Button("Respring") {
                                mgr.respring()
                            }
                        }
                        
                        Button("Panic!") {
                            mgr.panic()
                        }
                        .disabled(!mgr.dsready)
                        
                        Button("gettask") {
                            ourtask(ourproc())
                        }
                        .disabled(!mgr.dsready)
                    } header: {
                        Text("Other")
                    }
                }
                
                Section {
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/rooootdev.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("roooot")
                                .font(.headline)
                            
                            Text("Main Developer")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/rooootdev"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/AppInstalleriOSGH.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("AppInstaller iOS")
                                .font(.headline)
                            
                            Text("Helped me with offsets and other stuff. This project wouldnt have been possible without him!")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/AppInstalleriOSGH"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Credits")
                }
            }
            .navigationTitle("lara")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showresetalert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("Clear Kernelcache Data?", isPresented: $showresetalert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                clearkerncachedata()
                hasoffsets = haskernproc()
            }
        } message: {
            Text("This will delete the downloaded kernelcache and remove saved offsets.")
        }
    }
}
