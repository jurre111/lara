//
//  ApplicationManager.swift
//  lara
//
//  Created by ruter on 05.04.26.
//

import Foundation
import UIKit

class ApplicationManager {
    private static let fm = FileManager.default
    
    private static let systemApplicationsUrl = URL(fileURLWithPath: "/Applications", isDirectory: true)
    private static let userApplicationsUrl = URL(fileURLWithPath: "/var/containers/Bundle/Application", isDirectory: true)
    
    static func getApps() throws -> [SBApp] {
        var dotAppDirs: [URL] = []
        
        // Get system apps
        let systemAppsDir = try fm.contentsOfDirectory(at: systemApplicationsUrl, includingPropertiesForKeys: nil)
        dotAppDirs += systemAppsDir
        
        // Get user apps
        if let userAppFolders = try? fm.contentsOfDirectory(at: userApplicationsUrl, includingPropertiesForKeys: nil) {
            for userAppFolder in userAppFolders {
                let userAppFolderContents = try? fm.contentsOfDirectory(at: userAppFolder, includingPropertiesForKeys: nil)
                if let dotApp = userAppFolderContents?.first(where: { $0.absoluteString.hasSuffix(".app/") }) {
                    dotAppDirs.append(dotApp)
                }
            }
        }
        
        var apps: [SBApp] = []
        
        for bundleUrl in dotAppDirs {
            let infoPlistUrl = bundleUrl.appendingPathComponent("Info.plist")
            if !fm.fileExists(atPath: infoPlistUrl.path) {
                continue
            }
            
            guard let infoPlist = NSDictionary(contentsOf: infoPlistUrl) as? [String: AnyObject] else {
                continue
            }
            guard let CFBundleIdentifier = infoPlist["CFBundleIdentifier"] as? String else {
                continue
            }
            
            // Get display name with better fallbacks
            var appName = "Unknown"
            if let CFBundleDisplayName = infoPlist["CFBundleDisplayName"] as? String, !CFBundleDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
                appName = CFBundleDisplayName
            } else if let CFBundleName = infoPlist["CFBundleName"] as? String, !CFBundleName.trimmingCharacters(in: .whitespaces).isEmpty {
                appName = CFBundleName
            } else if let CFBundleExecutable = infoPlist["CFBundleExecutable"] as? String, !CFBundleExecutable.trimmingCharacters(in: .whitespaces).isEmpty {
                appName = CFBundleExecutable
            }
            
            var app = SBApp(
                bundleIdentifier: CFBundleIdentifier,
                name: appName,
                version: infoPlist["CFBundleShortVersionString"] as? String ?? "1.0",
                bundleURL: bundleUrl,
                pngIconPaths: [],
                hiddenFromSpringboard: false
            )
            
            // Collect PNG icon paths
            if let CFBundleIcons = infoPlist["CFBundleIcons"] as? [String: AnyObject] {
                if let CFBundlePrimaryIcon = CFBundleIcons["CFBundlePrimaryIcon"] as? [String: AnyObject] {
                    if let CFBundleIconFiles = CFBundlePrimaryIcon["CFBundleIconFiles"] as? [String] {
                        app.pngIconPaths += CFBundleIconFiles.map { $0 + "@2x.png" }
                    }
                }
            }
            
            if let CFBundleIconFile = infoPlist["CFBundleIconFile"] as? String {
                app.pngIconPaths.append(CFBundleIconFile + ".png")
            }
            
            if let CFBundleIconFiles = infoPlist["CFBundleIconFiles"] as? [String], !CFBundleIconFiles.isEmpty {
                app.pngIconPaths += CFBundleIconFiles.map { $0.replacingOccurrences(of: ".png", with: "") + ".png" }
            }
            
            // Check if hidden
            if let SBAppTags = infoPlist["SBAppTags"] as? [String], !SBAppTags.isEmpty {
                if SBAppTags.contains("hidden") {
                    app.hiddenFromSpringboard = true
                }
            }
            
            apps.append(app)
        }
        
        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

struct SBApp: Identifiable {
    let id = UUID()
    
    var bundleIdentifier: String
    var name: String
    var version: String
    var bundleURL: URL
    var pngIconPaths: [String]
    var hiddenFromSpringboard: Bool
    
    var isSystem: Bool {
        bundleURL.pathComponents.count >= 2 && bundleURL.pathComponents[1] == "Applications"
    }
    
    var icon: UIImage? {
        loadIcon()
    }
    
    private func loadIcon() -> UIImage? {
        guard let bundle = Bundle(path: bundleURL.path) else { return nil }
        
        // Get Assets.car and extract the app icon
        let assetsCarPath = bundleURL.appendingPathComponent("Assets.car").path
        let fm = FileManager.default
        
        if fm.fileExists(atPath: assetsCarPath) {
            if let image = extractImageFromAssetsCar(path: assetsCarPath) {
                return image
            }
        }
        
        return nil
    }
    
    private func extractImageFromAssetsCar(path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        
        let bytes = [UInt8](data)
        
        // Search for PNG header (89 50 4E 47)
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        // Search for JPEG header (FF D8 FF)
        let jpegHeader: [UInt8] = [0xFF, 0xD8, 0xFF]
        
        // Look for PNG
        if let pngRange = findImageData(in: bytes, header: pngHeader, endMarker: [0x49, 0x45, 0x4E, 0x44]) {
            if let image = UIImage(data: data.subdata(in: pngRange)) {
                return image
            }
        }
        
        // Look for JPEG
        if let jpegStart = findImageStart(in: bytes, header: jpegHeader) {
            if let jpegEnd = findJPEGEnd(in: bytes, start: jpegStart) {
                let jpegRange = jpegStart..<jpegEnd
                if let image = UIImage(data: data.subdata(in: jpegRange)) {
                    return image
                }
            }
        }
        
        return nil
    }
    
    private func findImageStart(in bytes: [UInt8], header: [UInt8]) -> Int? {
        guard !header.isEmpty else { return nil }
        
        for i in 0...(bytes.count - header.count) {
            if bytes[i..<(i + header.count)].elementsEqual(header) {
                return i
            }
        }
        return nil
    }
    
    private func findImageData(in bytes: [UInt8], header: [UInt8], endMarker: [UInt8]) -> Range<Int>? {
        guard let start = findImageStart(in: bytes, header: header) else { return nil }
        guard let endIndex = findImageEnd(in: bytes, start: start, endMarker: endMarker) else { return nil }
        
        return start..<(endIndex + endMarker.count)
    }
    
    private func findImageEnd(in bytes: [UInt8], start: Int, endMarker: [UInt8]) -> Int? {
        guard !endMarker.isEmpty else { return nil }
        
        for i in start...(bytes.count - endMarker.count) {
            if bytes[i..<(i + endMarker.count)].elementsEqual(endMarker) {
                return i
            }
        }
        return nil
    }
    
    private func findJPEGEnd(in bytes: [UInt8], start: Int) -> Int? {
        // JPEG ends with FF D9
        let jpegEnd: [UInt8] = [0xFF, 0xD9]
        
        for i in start...(bytes.count - jpegEnd.count) {
            if bytes[i..<(i + jpegEnd.count)].elementsEqual(jpegEnd) {
                return i + jpegEnd.count
            }
        }
        return nil
    }
}
