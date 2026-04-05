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
            
            var app = SBApp(
                bundleIdentifier: CFBundleIdentifier,
                name: "Unknown",
                version: infoPlist["CFBundleShortVersionString"] as? String ?? "1.0",
                bundleURL: bundleUrl,
                pngIconPaths: [],
                hiddenFromSpringboard: false
            )
            
            // Get display name
            if let CFBundleDisplayName = infoPlist["CFBundleDisplayName"] as? String {
                app.name = CFBundleDisplayName
            } else if let CFBundleName = infoPlist["CFBundleName"] as? String {
                app.name = CFBundleName
            }
            
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
        
        // Get current appearance (light/dark mode)
        let traitCollection = UITraitCollection.current
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        // Try CFBundleIcons from Assets.car first
        if let icons = bundle.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] {
            
            // Get icon name from plist
            if let iconName = primary["CFBundleIconName"] as? String {
                // Try loading from Assets.car with appearance
                let appearanceVariant = isDarkMode ? "~dark" : ""
                if let image = UIImage(named: iconName + appearanceVariant, in: bundle, compatibleWith: nil) {
                    return image
                }
                // Fallback to base icon name
                if let image = UIImage(named: iconName, in: bundle, compatibleWith: nil) {
                    return image
                }
            }
            
            // Try CFBundleIconFiles from Assets.car
            if let files = primary["CFBundleIconFiles"] as? [String] {
                for name in files.reversed() {
                    let appearanceVariant = isDarkMode ? "~dark" : ""
                    if let image = UIImage(named: name + appearanceVariant, in: bundle, compatibleWith: nil) {
                        return image
                    }
                    if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                        return image
                    }
                }
            }
        }
        
        // Try CFBundleIconFile from Assets.car
        if let name = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            let appearanceVariant = isDarkMode ? "~dark" : ""
            if let image = UIImage(named: name + appearanceVariant, in: bundle, compatibleWith: nil) {
                return image
            }
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
        }
        
        // Try CFBundleIcons~ipad as fallback
        if let icons = bundle.infoDictionary?["CFBundleIcons~ipad"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String] {
            for name in files.reversed() {
                let appearanceVariant = isDarkMode ? "~dark" : ""
                if let image = UIImage(named: name + appearanceVariant, in: bundle, compatibleWith: nil) {
                    return image
                }
                if let image = UIImage(named: name, in: bundle, compatibleWith: nil) {
                    return image
                }
            }
        }
        
        // Load PNG icon directly from pngIconPaths as last resort
        for iconPath in pngIconPaths {
            let fullPath = bundleURL.appendingPathComponent(iconPath).path
            if FileManager.default.fileExists(atPath: fullPath) {
                if let image = UIImage(contentsOfFile: fullPath) {
                    return image
                }
            }
        }
        
        return nil
    }
}
