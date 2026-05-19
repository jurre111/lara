import Foundation
import Combine
import UIKit

final class webdavmgr: ObservableObject {
    @Published var webdav: GCDWebDAVServer?
    @Published var path: String = "/"
    @Published var serverstarted: Bool = false
    @Published var url: String?
    @Published var showhiddenfiles: Bool = true

    static let shared = webdavmgr()
    private var bg: UIBackgroundTaskIdentifier = .invalid


    func startserver() -> (ok: Bool, message: String) {
        let customdavpath = UserDefaults.standard.string(forKey: "customdavpath")
        guard !serverstarted else { return (false, "A WebDAV server is already running") }
        guard FileManager.default.fileExists(atPath: path) else { return  (false, "The path \(path) does not exist") }
        let server = GCDWebDAVServer(uploadDirectory: customdavpath != nil ? customdavpath! : path)
        server.allowHiddenItems = showhiddenfiles

        var error: NSError? = nil
        let options: [String: Any] = [GCDWebServerOption_AutomaticallySuspendInBackground: false]
        let started = server.start(withOptions: options, error: &error)
        
        DispatchQueue.main.async {
            if started {
                self.webdav = server
                self.serverstarted = true
                self.url = webdav?.serverURL?.absoluteString
            } else {
                self.webdav = nil
                self.serverstarted = false
                self.url = nil
            }
        }
        return (self.serverstarted, self.serverstarted ? "Started WebDAV in path \(path) on url \(self.url ?? "oops")" : "failed starting WebDAV server in path \(path)")
    }

    func stopserver() -> (ok: Bool, message: String) {
        guard serverstarted, let server = webdav else { return (false, "No WebDAV server is currently running") }
        server.stop()
        self.webdav = nil
        self.serverstarted = false
        self.url = nil
        return (true, "Stopped WebDAV in path \(path) on url \(self.url ?? "oops")")
    }

    func startbg() {
        guard bg == .invalid else { return }
        bg = UIApplication.shared.beginBackgroundTask(withName: "davserver") {
            UIApplication.shared.endBackgroundTask(self.bg)
            self.bg = .invalid
        }
    }

    func endbg() {
        guard bg != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bg)
        bg = .invalid
    }
}