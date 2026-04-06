//
//  lara.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

let g_isunsupported: Bool = isunsupported()

extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

@main
struct lara: App {
    @ObservedObject private var mgr = laramgr.shared
    @Environment(\.scenePhase) private var scenePhase
    @State var showunsupported: Bool = false
    @State private var selectedtab: Int = 1
    private let keepalivekey = "keepalive"
    @AppStorage("showfmintabs") private var showfmintabs: Bool = true
    @AppStorage("selectedmethod") private var selectedmethod: method = .sbx

    init() {
        // fix file picker
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
        
        if UserDefaults.standard.string(forKey: "selectedmethod") == nil {
            UserDefaults.standard.set(method.sbx.rawValue, forKey: "selectedmethod")
        }
        if g_isunsupported {
            showunsupported = true
        }
        
        if UserDefaults.standard.bool(forKey: keepalivekey) {
            if !kaenabled {
                toggleka()
            }
        }
        
        if g_isunsupported {
            print("device may be unsupported")
        } else {
            print("device should be supported")
        }
        
        globallogger.capture()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedtab) {
                SantanderView(startPath: "/")
                    .tabItem {
                        Image(systemName: "folder.fill")
                    }
                    .tag(0)
                
                ContentView()
                    .tabItem {
                        Image(systemName: "ant.fill")
                    }
                    .tag(1)
                
                LogsView(logger: globallogger)
                    .tabItem {
                        Image(systemName: "doc.text.fill")
                    }
                    .tag(2)
            }
            .onAppear {
                if g_isunsupported {
                    showunsupported = true
                }
                
                init_offsets()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    globallogger.stopcapture()
                } else if phase == .active {
                    globallogger.capture()
                }
            }
            .alert(isPresented: $showunsupported) {
                .init(title: Text("Unsupported"), message: Text("Lara is currently not supported on this device. Possible reasons:\nYour device is newer than iOS 26.0.1\nYour device is older than iOS 17.0\nYour device has MIE\nYou installed lara via LiveContainer\n\nLara will probably not work."))
            }
        }
    }
}
