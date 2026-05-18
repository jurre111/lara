import Foundation
import Combine

final class webdavmgr: ObservableObject {
    @Published var webdav: GCDWebDAVServer?
    @Published var path: String = "/"
    @Published var serverstarted: Bool = false
    @Published var url: String?
    @Published var showhiddenfiles: Bool = true

    @AppStorage("customdavpath") private var customdavpath: String?

    static let shared = webdavmgr()

    func startserver() -> (ok: Bool, message: String) {
        guard !serverstarted else { return (false, "A WebDAV server is already running") }
        guard FileManager.default.fileExists(atPath: path) else { return  (false, "The path \(path) does not exist") }
        let server = GCDWebDAVServer(uploadDirectory: customdavpath!= nil ? customdavpath! : path)
        server.allowHiddenItems = showhiddenfiles
        if server.start() {
            self.webdav = server
            self.serverstarted = true
            self.url = webdav?.serverURL?.absoluteString
            return (true, "Started WebDAV in path \(path) on url \(self.url ?? "oops")")
        } else {
            return (false, "failed starting WebDAV server in path \(path)")
        }
    }

    func stopserver() -> (ok: Bool, message: String) {
        guard serverstarted, let server = webdav else { return (false, "No WebDAV server is currently running") }
        server.stop()
        self.webdav = nil
        self.serverstarted = false
        self.url = nil
        return (true, "Stopped WebDAV in path \(path) on url \(self.url ?? "oops")")
    }
}