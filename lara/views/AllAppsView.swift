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
        ZStack(alignment: .top) {
            ScrollView {
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
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            HStack(spacing: 10) {
                                if let icon = app.icon {
                                    Image(uiImage: icon)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8.9, style: .continuous))
                                } else {
                                    Image(systemName: "app")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name ?? "Unknown App")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(app.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                    .padding()
                }
            }
            .padding(.top, 60)
            
            VStack {
                SearchBar(text: $searchText)
                Divider()
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("All Applications (\(allApps.count))")
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
