//
//  AllAppsView.swift
//  lara
//
//  Created by ruter on 05.04.26.
//

import SwiftUI

struct AllAppsView: View {
    @State private var allApps: [SBApp] = []
    @State private var isLoadingApps = false
    @State private var searchText = ""
    @State private var iconWidth = 60.0
    
    var filteredApps: [SBApp] {
        if searchText.isEmpty {
            return allApps
        }
        return allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadAllApps() {
        isLoadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let apps = try ApplicationManager.getApps()
                DispatchQueue.main.async {
                    allApps = apps
                    isLoadingApps = false
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingApps = false
                }
            }
        }
    }
    
    var body: some View {
        List {
            Slider(value: $iconWidth, in: 30...120, step: 1) {
                Text("Icon Size")
            }
            if isLoadingApps {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if filteredApps.isEmpty {
                Text("No apps found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(filteredApps) { app in
                    Section {
                        HStack(spacing: 12) {
                            if let icon = app.icon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .frame(width: iconWidth, height: iconWidth)
                                    .clipShape(RoundedRectangle(cornerRadius: iconWidth/2*0.4453125, style: .continuous))
                            } else {
                                Image(systemName: "app")
                                    .resizable()
                                    .frame(width: iconWidth, height: iconWidth)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(app.name ?? "Unknown App")
                                    .font(.headline)
                                Spacer()
                                Text(app.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(height: iconWidth)
                                
                                // HStack(spacing: 8) {
                                //     if app.isSystem {
                                //         Label("System", systemImage: "star.fill")
                                //             .font(.caption2)
                                //             .foregroundColor(.orange)
                                //     } else {
                                //         Label("User", systemImage: "person")
                                //             .font(.caption2)
                                //             .foregroundColor(.blue)
                                //     }
                                //     
                                //     if app.hiddenFromSpringboard {
                                //         Label("Hidden", systemImage: "eye.slash")
                                //             .font(.caption2)
                                //             .foregroundColor(.gray)
                                //     }
                                //     
                                //     Spacer()
                                //     
                                //     Text("v\(app.version)")
                                //         .font(.caption2)
                                //         .foregroundColor(.secondary)
                                // }
                        }
                    }
                }
            }
        }
        .navigationTitle("All Applications (\(allApps.count))")
        .searchable(text: $searchText, prompt: "Search apps")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loadAllApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadAllApps()
        }
    }
}
