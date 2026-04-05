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
        
        // Try standard AppIcon names
        let standardNames = ["AppIcon", "AppIcon60x60", "AppIcon180", "AppIcon152", "AppIcon144", "AppIcon120"]
        for name in standardNames {
            if let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current) {
                globallogger.log("[Icon] ✓ \(self.name): \(name)")
                return image
            }
        }
        
        // Try CFBundleIcons from Info.plist
        if let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
            if let iconName = primary["CFBundleIconName"] as? String {
                if let image = UIImage(named: iconName, in: bundle, compatibleWith: UITraitCollection.current) {
                    globallogger.log("[Icon] ✓ \(self.name): CFBundleIconName")
                    return image
                }
            }
            if let files = primary["CFBundleIconFiles"] as? [String] {
                for name in files {
                    if let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current) {
                        globallogger.log("[Icon] ✓ \(self.name): CFBundleIconFiles")
                        return image
                    }
                }
            }
        }
        
        // Try Assets.car parsing for common icon names
        let assetsCarPath = bundleURL.appendingPathComponent("Assets.car").path
        if FileManager.default.fileExists(atPath: assetsCarPath) {
            for iconName in standardNames {
                if let image = extractIconFromAssetsCar(at: assetsCarPath, iconName: iconName) {
                    globallogger.log("[Icon] ✓ \(self.name): extracted \(iconName) from Assets.car")
                    return image
                }
            }
        }
        
        // PNG fallback
        for iconPath in pngIconPaths {
            let fullPath = bundleURL.appendingPathComponent(iconPath).path
            if FileManager.default.fileExists(atPath: fullPath),
               let image = UIImage(contentsOfFile: fullPath) {
                globallogger.log("[Icon] ✓ \(self.name): PNG")
                return image
            }
        }
        
        return nil
    }
    
    private func extractIconFromAssetsCar(at path: String, iconName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        
        let bytes = [UInt8](data)
        
        // Assets.car format: Look for PNG/JPEG data in the file
        // Start with a simple approach: find the first large PNG or JPEG
        
        // Search for PNG (89 50 4E 47)
        if let image = findAndCreateImage(in: bytes, 
                                          headerBytes: [0x89, 0x50, 0x4E, 0x47],
                                          endBytes: [0x49, 0x45, 0x4E, 0x44],
                                          data: data) {
            return image
        }
        
        // Search for JPEG (FF D8 FF E0 or FF D8 FF E1, etc.)
        if let image = findAndCreateJPEGImage(in: bytes, data: data) {
            return image
        }
        
        return nil
    }
    
    private func findAndCreateImage(in bytes: [UInt8], 
                                     headerBytes: [UInt8], 
                                     endBytes: [UInt8], 
                                     data: Data) -> UIImage? {
        var currentIndex = 0
        
        while currentIndex < bytes.count - headerBytes.count {
            // Find header
            if bytes[currentIndex..<(currentIndex + headerBytes.count)].elementsEqual(headerBytes) {
                // Found header, now find end
                var endIndex = currentIndex + 100
                while endIndex < bytes.count - endBytes.count {
                    if bytes[endIndex..<(endIndex + endBytes.count)].elementsEqual(endBytes) {
                        // Found end, extract image
                        let imageData = data.subdata(in: currentIndex..<(endIndex + endBytes.count))
                        if let image = UIImage(data: imageData) {
                            return image
                        }
                        endIndex += 100
                    } else {
                        endIndex += 1
                    }
                }
            }
            currentIndex += 1
        }
        
        return nil
    }
    
    private func findAndCreateJPEGImage(in bytes: [UInt8], data: Data) -> UIImage? {
        var currentIndex = 0
        
        while currentIndex < bytes.count - 3 {
            // Look for JPEG start (FF D8 FF)
            if bytes[currentIndex] == 0xFF && bytes[currentIndex + 1] == 0xD8 && bytes[currentIndex + 2] == 0xFF {
                // Found start, look for end (FF D9)
                var endIndex = currentIndex + 100
                while endIndex < bytes.count - 1 {
                    if bytes[endIndex] == 0xFF && bytes[endIndex + 1] == 0xD9 {
                        // Found end
                        let imageData = data.subdata(in: currentIndex..<(endIndex + 2))
                        if let image = UIImage(data: imageData) {
                            return image
                        }
                        endIndex += 100
                    } else {
                        endIndex += 1
                    }
                }
            }
            currentIndex += 1
        }
        
        return nil
    }
}
