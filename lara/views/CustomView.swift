//
//  CustomView.swift
//  lara
//
//  Created by ruter on 29.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct CustomView: View {
    @ObservedObject var mgr: laramgr
    @State private var targetPath: String = "/"
    @State private var showImporter = false
    @State private var sourcePath: String = ""
    @State private var sourceName: String = "No file selected"
    @State private var isOverwriting = false

    var body: some View {
        List {
            Section {
                TextField("/path/to/target", text: $targetPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                HStack {
                    Text("Source")
                    Spacer()
                    Text(sourceName)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("Choose Source File") {
                    showImporter = true
                }

                Button(isOverwriting ? "Overwriting..." : "Overwrite Target") {
                    guard !isOverwriting else { return }
                    overwrite()
                }
                .disabled(!canOverwrite)
            } header: {
                Text("Custom Path Overwrite")
            } footer: {
                Text("This will overwrite the target file with the contents of the selected source file. Target size must be >= source size.")
            }

            Section {
                Text(globallogger.logs.last ?? "No logs yet")
                    .font(.system(size: 13, design: .monospaced))
            }
        }
        .navigationTitle("Custom Overwrite")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importSource(url)
            }
        }
    }

    private var canOverwrite: Bool {
        mgr.vfsready && !targetPath.isEmpty && !sourcePath.isEmpty && !isOverwriting
    }

    private func importSource(_ url: URL) {
        let fm = FileManager.default
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dest = tmpDir.appendingPathComponent("vfs_custom_\(UUID().uuidString)")

        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: url, to: dest)
            sourcePath = dest.path
            sourceName = url.lastPathComponent
            mgr.logmsg("selected source: \(sourceName)")
        } catch {
            mgr.logmsg("failed to import source: \(error.localizedDescription)")
        }
    }

    private func overwrite() {
        guard canOverwrite else { return }
        isOverwriting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = mgr.vfsoverwritefromlocalpath(target: targetPath, source: sourcePath)
            DispatchQueue.main.async {
                isOverwriting = false
                ok ? mgr.logmsg("overwrite ok: \(targetPath)") : mgr.logmsg("overwrite failed: \(targetPath)")
            }
        }
    }
}

