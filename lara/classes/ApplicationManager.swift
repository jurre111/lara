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
        guard let bundle = Bundle(path: bundleURL.path) else {
            globallogger.log("[Icon] Failed to load bundle for \(name)")
            return nil
        }
        
        globallogger.log("[Icon] Loading: \(name)")
        
        // Check if Assets.car exists
        let assetsCarPath = bundleURL.appendingPathComponent("Assets.car").path
        let hasAssetsCar = FileManager.default.fileExists(atPath: assetsCarPath)
        
        // Try standard AppIcon names first
        let standardNames = ["AppIcon", "AppIcon60x60", "AppIcon180", "AppIcon152", "AppIcon144", "AppIcon120"]
        for name in standardNames {
            if let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current) {
                globallogger.log("[Icon] ✓ \(self.name): loaded \(name)")
                return image
            }
        }
        
        // Try CFBundleIcons from Info.plist
        if let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
            if let iconName = primary["CFBundleIconName"] as? String {
                if let image = UIImage(named: iconName, in: bundle, compatibleWith: UITraitCollection.current) {
                    globallogger.log("[Icon] ✓ \(self.name): loaded CFBundleIconName \(iconName)")
                    return image
                }
            }
            if let files = primary["CFBundleIconFiles"] as? [String] {
                for name in files {
                    if let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current) {
                        globallogger.log("[Icon] ✓ \(self.name): loaded CFBundleIconFiles \(name)")
                        return image
                    }
                }
            }
        }
        
        // If Assets.car exists and UIImage failed, parse it directly
        if hasAssetsCar {
            globallogger.log("[Icon] Parsing Assets.car directly for \(self.name)")
            if let image = extractIconFromAssetsCar(assetsCarPath) {
                globallogger.log("[Icon] ✓ \(self.name): extracted from Assets.car")
                return image
            }
        }
        
        // Final fallback: PNG files
        for iconPath in pngIconPaths {
            let fullPath = bundleURL.appendingPathComponent(iconPath).path
            if FileManager.default.fileExists(atPath: fullPath),
               let image = UIImage(contentsOfFile: fullPath) {
                globallogger.log("[Icon] ✓ \(self.name): loaded PNG")
                return image
            }
        }
        
        globallogger.log("[Icon] ✗ \(self.name): no icon found")
        return nil
    }
    
    private func extractIconFromAssetsCar(_ path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        
        let bytes = [UInt8](data)
        
        // Search for PNG headers (89 50 4E 47)
        if let pngRange = findImageRange(in: bytes, headerPrefix: [0x89, 0x50, 0x4E, 0x47], headerSuffix: [0x49, 0x45, 0x4E, 0x44]) {
            if let image = UIImage(data: data.subdata(in: pngRange)) {
                return image
            }
        }
        
        // Search for JPEG headers (FF D8 FF)
        if let jpegRange = findJPEGRange(in: bytes) {
            if let image = UIImage(data: data.subdata(in: jpegRange)) {
                return image
            }
        }
        
        return nil
    }
    
    private func findImageRange(in bytes: [UInt8], headerPrefix: [UInt8], headerSuffix: [UInt8]) -> Range<Int>? {
        guard let start = findPattern(in: bytes, pattern: headerPrefix) else { return nil }
        guard let end = findPattern(in: bytes, pattern: headerSuffix, startIndex: start) else { return nil }
        
        return start..<(end + headerSuffix.count)
    }
    
    private func findJPEGRange(in bytes: [UInt8]) -> Range<Int>? {
        guard let start = findPattern(in: bytes, pattern: [0xFF, 0xD8, 0xFF]) else { return nil }
        guard let end = findPattern(in: bytes, pattern: [0xFF, 0xD9], startIndex: start) else { return nil }
        
        return start..<(end + 2)
    }
    
    private func findPattern(in bytes: [UInt8], pattern: [UInt8], startIndex: Int = 0) -> Int? {
        guard pattern.count <= bytes.count - startIndex else { return nil }
        
        for i in startIndex...(bytes.count - pattern.count) {
            if bytes[i..<(i + pattern.count)].elementsEqual(pattern) {
                return i
            }
        }
        return nil
    }
}
