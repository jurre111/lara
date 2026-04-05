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
            globallogger.log("[Icon] Failed to load bundle for \(name) at \(bundleURL.path)")
            return nil
        }
        
        globallogger.log("[Icon] Loading icon for: \(name)")
        
        // Check if Assets.car exists and if we can read files
        let assetsCarPath = bundleURL.appendingPathComponent("Assets.car").path
        let hasAssetsCar = FileManager.default.fileExists(atPath: assetsCarPath)
        globallogger.log("[Icon]   Has Assets.car: \(hasAssetsCar)")
        
        // Test bundle file permissions
        let infoPlistPath = bundleURL.appendingPathComponent("Info.plist").path
        let canReadBundle = FileManager.default.fileExists(atPath: infoPlistPath)
        globallogger.log("[Icon]   Can read bundle: \(canReadBundle)")
        
        // Comprehensive list of common icon names used in iOS apps
        let possibleIconNames = [
            "AppIcon",
            "AppIcon60x60",
            "AppIcon-60",
            "icon",
            "Icon",
            "AppIcon1024",
            "AppIcon180",
            "AppIcon167",
            "AppIcon152",
            "AppIcon144",
            "AppIcon120",
            "AppIcon114",
            "AppIcon76",
            "AppIcon72",
            "AppIcon57",
            "App",
            "app",
            "logo",
            "Logo",
            "Product Icon Simple iOS"
        ]
        
        // Try loading each icon name with current trait
        globallogger.log("[Icon]   Trying standard icon names...")
        for name in possibleIconNames {
            let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current)
            if image != nil {
                globallogger.log("[Icon]   ✓ Found icon: \(name)")
                return image
            }
        }
        globallogger.log("[Icon]   ✗ No standard icon names worked")
        
        // Try CFBundleIcons from Info.plist with detailed logging
        globallogger.log("[Icon]   Trying CFBundleIcons from Info.plist...")
        if let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any] {
            globallogger.log("[Icon]     CFBundleIcons keys: \(Array(icons.keys).joined(separator: ", "))")
            
            if let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
                globallogger.log("[Icon]     CFBundlePrimaryIcon keys: \(Array(primary.keys).joined(separator: ", "))")
                
                if let iconName = primary["CFBundleIconName"] as? String {
                    globallogger.log("[Icon]     CFBundleIconName: \(iconName)")
                    let img = UIImage(named: iconName, in: bundle, compatibleWith: UITraitCollection.current)
                    globallogger.log("[Icon]     UIImage result: \(img != nil ? "found" : "nil")")
                    if img != nil {
                        globallogger.log("[Icon]     ✓ Found icon from CFBundleIconName")
                        return img
                    }
                }
                
                if let files = primary["CFBundleIconFiles"] as? [String] {
                    globallogger.log("[Icon]     CFBundleIconFiles: \(files)")
                    for name in files {
                        let img = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current)
                        if img != nil {
                            globallogger.log("[Icon]     ✓ Found icon: \(name)")
                            return img
                        }
                    }
                    globallogger.log("[Icon]     No CFBundleIconFiles loaded")
                }
            }
        } else {
            globallogger.log("[Icon]     No CFBundleIcons in Info.plist")
        }
        
        // Try CFBundleIconFile
        globallogger.log("[Icon]   Trying CFBundleIconFile...")
        if let name = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            globallogger.log("[Icon]     CFBundleIconFile: \(name)")
            if let image = UIImage(named: name, in: bundle, compatibleWith: UITraitCollection.current) {
                globallogger.log("[Icon]     ✓ Found icon")
                return image
            }
        }
        
        // Try direct Assets.car parsing
        if hasAssetsCar {
            globallogger.log("[Icon]   Trying direct Assets.car parsing...")
            do {
                let carData = try Data(contentsOf: URL(fileURLWithPath: assetsCarPath))
                globallogger.log("[Icon]     Assets.car size: \(carData.count) bytes")
                
                // Try to find PNG or JPEG in the file
                let bytes = [UInt8](carData)
                
                // Search for PNG (89 50 4E 47)
                for i in 0..<(bytes.count - 4) {
                    if bytes[i] == 0x89 && bytes[i+1] == 0x50 && bytes[i+2] == 0x4E && bytes[i+3] == 0x47 {
                        globallogger.log("[Icon]     Found PNG at offset \(i)")
                        // Try to find end of PNG (IEND)
                        var endIdx = i + 100
                        while endIdx < bytes.count - 4 {
                            if bytes[endIdx] == 0x49 && bytes[endIdx+1] == 0x45 && bytes[endIdx+2] == 0x4E && bytes[endIdx+3] == 0x44 {
                                let pngData = carData.subdata(in: i..<(endIdx + 8))
                                if let image = UIImage(data: pngData) {
                                    globallogger.log("[Icon]     ✓ Extracted PNG from Assets.car")
                                    return image
                                }
                                break
                            }
                            endIdx += 1
                        }
                    }
                }
            } catch {
                globallogger.log("[Icon]     Failed to read Assets.car: \(error)")
            }
        }
        
        // Fallback to PNG files in bundle
        globallogger.log("[Icon]   Trying PNG fallback (\(pngIconPaths.count) paths)...")
        for iconPath in pngIconPaths {
            let fullPath = bundleURL.appendingPathComponent(iconPath).path
            if FileManager.default.fileExists(atPath: fullPath) {
                globallogger.log("[Icon]     Trying: \(iconPath)")
                if let image = UIImage(contentsOfFile: fullPath) {
                    globallogger.log("[Icon]     ✓ Loaded PNG")
                    return image
                }
            }
        }
        
        globallogger.log("[Icon]   ✗ Failed to load icon for \(name)")
        return nil
    }
}
