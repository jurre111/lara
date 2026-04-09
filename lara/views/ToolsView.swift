//
//  ToolsView.swift
//  lara
//
//  Created by ruter on 04.04.26.
//

import SwiftUI

struct ToolsView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var isaslr: Bool = aslrstate
    @State var showtoken: Bool = false
    @AppStorage("token") var token: String?
    @State private var uid: uid_t = getuid()
    @State private var pid: pid_t = getpid()
    
    var body: some View {
        List {
            if !mgr.dsready {
                Section {
                    Text("Kernel R/W is not ready. Run the exploit first.")
                        .foregroundColor(.secondary)
                } header: {
                    Text("Status")
                }
            }

            Section {
                HStack {
                    Text("ASLR:")
                    
                    Spacer()
                    
                    Text(isaslr ? "enabled" : "disabled")
                        .foregroundColor(isaslr ? Color.red : Color.green)
                        .monospaced()
                    
                    Button {
                        isaslr = aslrstate
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                Button {
                    toggleaslr()
                    isaslr = aslrstate
                } label: {
                    Text("Toggle ASLR")
                }
            } header: {
                Text("ASLR")
            } footer: {
                Text("Address Space Layout Randomization. Turning it on may break lara.")
            }
            
            
            if 1 == 2 {
                Section {
                    NavigationLink("LaraJIT") {
                        JitView()
                    }
                    .disabled(!mgr.sbxready)
                } header: {
                    Text("Tools")
                }
            }
            
            Section {
                Button {
                    globallogger.log(String(format: "0x%llx",procbyname("springboard")))
                    // killproc("springboard")
                } label: {
                    Text("Respring (probably broken)")
                }
                
                HStack {
                    Text("ourproc: ")
                    Spacer()
                    Text(mgr.dsready ? String(format: "0x%llx", ds_get_our_proc()) : "N/A")
                        .foregroundColor(.secondary)
                        .monospaced()
                }
                
                HStack {
                    Text("ourtask: ")
                    Spacer()
                    Text(mgr.dsready ? String(format: "0x%llx", ds_get_our_task()) : "N/A")
                        .foregroundColor(.secondary)
                        .monospaced()
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
            } header: {
                Text("Process")
            }

            Section {
                HStack {
                    if showtoken {
                        Text(mgr.sbxready ? "tkn" : "No Saved Token.")
                            .foregroundColor(.secondary)
                            .monospaced()
                            .lineLimit(nil)
                    } else {
                        if let token = token, !token.isEmpty {
                            SecureField("", text: .constant(token))
                                .textFieldStyle(.plain)
                                .disabled(true)
                                .allowsHitTesting(false)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("No Saved Token.")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        UIPasteboard.general.string = token ?? ""
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .contextMenu {
                    if token != nil {
                        Button {
                            UIPasteboard.general.string = token ?? ""
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                }
                
                Button {
                    token = mgr.sbxgettoken(path: "/var/mobile")
                } label: {
                    Text("Issue Token")
                }
                .disabled(!mgr.sbxready)
            } header: {
                Text("Sandbox")
            } footer: {
                Text("Likely broken.")
            }
        }
        .navigationTitle("Tools")
        .onAppear {
            if mgr.dsready {
                getaslrstate()
                isaslr = aslrstate
            }
        }
    }
}
