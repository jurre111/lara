//
//  SettingsView.swift
//  lara
//
//  Created by ruter on 29.03.26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var mgr: laramgr
    @Binding var hasoffsets: Bool
    @State private var showresetalert: Bool = false
    @State private var downloadingkernelcache = false
    @State private var showingKernelcacheImporter: Bool = false
    @State private var importingkernelcache: Bool = false
    @AppStorage("loggernobullshit") private var loggernobullshit: Bool = true
    @AppStorage("keepalive") private var iskeepalive: Bool = true
    @AppStorage("showfmintabs") private var showfmintabs: Bool = true
    @AppStorage("selectedmethod") private var selectedmethod: method = .hybrid
    @AppStorage("rcDockUnlimited") private var rcDockUnlimited: Bool = false
    
    var appname: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Unknown App"
    }
    var appversion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    var appicon: UIImage {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = UIImage(named: last) {
            return image
        }
        
        return UIImage(named: "unknown") ?? UIImage()
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(uiImage: appicon)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading) {
                            Text(appname)
                                .font(.headline)
                            
                            Text("Version \(appversion)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Lara")
                }
                
                
                Section {
                    Picker("", selection: $selectedmethod) {
                        ForEach(method.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Method")
                } footer: {
                    if selectedmethod == .vfs {
                        Text("VFS only.")
                    } else if selectedmethod == .sbx {
                        Text("SBX only.")
                    } else {
                        Text("Hybrid: SBX for read, VFS for write.\nBest method ever. (Thanks Huy)")
                    }
                }
                
                Section {
                    Toggle("Disable log dividers", isOn: $loggernobullshit)
                        .onChange(of: loggernobullshit) { _ in
                            globallogger.clear()
                        }
                    
                    Toggle("Keep Alive", isOn: $iskeepalive)
                        .onChange(of: iskeepalive) { _ in
                            if iskeepalive {
                                if !kaenabled { toggleka() }
                            } else {
                                if kaenabled { toggleka() }
                            }
                        }
                    
                    Toggle("Show File Manager in Tabs", isOn: $showfmintabs)

                } header: {
                    Text("Lara Settings")
                } footer: {
                    Text("Keep Alive keeps the app running in the background when it is minimized (not closed from app switcher).")
                }

                #if !DISABLE_REMOTECALL
                Section {
                    Toggle("Allow >10 dock icons", isOn: $rcDockUnlimited)
                } header: {
                    Text("RemoteCall")
                } footer: {
                    Text("Enables larger dock column counts in RemoteCall tweaks.")
                }
                #endif

                Section {
                    if !hasoffsets {
                        Button("Download Kernelcache") {
                            guard !downloadingkernelcache else { return }
                            downloadingkernelcache = true
                            DispatchQueue.global(qos: .userInitiated).async {
                                let ok = dlkerncache()
                                DispatchQueue.main.async {
                                    hasoffsets = ok
                                    downloadingkernelcache = false
                                }
                            }
                        }
                        .disabled(downloadingkernelcache)
                        
                        Button("Fetch Kernelcache") {
                            mgr.run()
                        }
                        
                        Button("Import Kernelcache from Files") {
                            guard !importingkernelcache else { return }
                            showingKernelcacheImporter = true
                        }
                        .disabled(importingkernelcache)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("How to obtain a kernelcache (macOS)")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.primary)

                            Text("1. Download the IPSW tool for your device.")
                            Link("https://github.com/blacktop/ipsw/releases",
                                 destination: URL(string: "https://github.com/blacktop/ipsw/releases")!)

                            Text("2. Extract the archive.")
                            Text("3. Open Terminal.")
                            Text("4. Navigate to the extracted folder:")
                            Text("cd /path/to/ipsw_3.1.671_something_something/")
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)

                            Text("5. Extract the kernel:")
                            Text("./ipsw extract --kernel [drag your ipsw here]")
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)

                            Text("6. Get the kernelcache file.")
                            Text("7. Transfer the kernelcache to your iCloud or iPhone.")
                            Text("8. Tap the button above and select the kernelcache, for example kernelcache.release.iPhone14,3.")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    }
                    
                    Button {
                        showresetalert = true
                    } label: {
                        Text("Delete Kernelcache Data")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Kernelcache")
                } footer: {
                    Text("Deleting and redownloading Kernelcache can fix a lot of issues. Try this before making a github Issue.")
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
                        AsyncImage(url: URL(string: "https://github.com/wh1te4ever.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("wh1te4ever")
                                .font(.headline)
                            
                            Text("Made darksword-kexploit-fun.")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/wh1te4ever"),
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
                            
                            Text("Helped me with offsets and lots of other stuff. This project wouldnt have been possible without him!")
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
                    
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/jailbreakdotparty.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("jailbreak.party")
                                .font(.headline)
                            
                            Text("All of the DirtyZero tweaks and emotional support.")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/jailbreakdotparty"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: "https://github.com/neonmodder123.png")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text("neon")
                                .font(.headline)
                            
                            Text("Made the respring script.")
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        
                        Spacer()
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://github.com/neonmodder123"),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                    }
                } header: {
                    Text("Credits")
                }
            }
            .navigationTitle("Settings")
        }
        .fileImporter(isPresented: $showingKernelcacheImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importingkernelcache = true
                DispatchQueue.global(qos: .userInitiated).async {
                    var ok = false
                    let shouldStopAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if shouldStopAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let fm = FileManager.default
                    if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let dest = docs.appendingPathComponent("kernelcache")
                        do {
                            if fm.fileExists(atPath: dest.path) {
                                try fm.removeItem(at: dest)
                            }
                            try fm.copyItem(at: url, to: dest)
                            ok = dlkerncache()
                        } catch {
                            print("failed to import kernelcache: \(error)")
                            ok = false
                        }
                    }
                    DispatchQueue.main.async {
                        hasoffsets = ok
                        importingkernelcache = false
                    }
                }
            case .failure:
                break
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

enum method: String, CaseIterable {
    case vfs = "VFS"
    case sbx = "SBX"
    case hybrid = "Hybrid"
}
