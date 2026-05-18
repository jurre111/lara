import SwiftUI
import Foundation

struct WebView: View {
    @State private var serverstarted = false
    @State private var path: String = "/"
    @State private var webdav: GCDWebDAVServer?
    var body: some View {
        List {
            Section {
                TextField("Path", text: $path)
                Button(serverstarted ? "Running..." : "Start WebDAV Server") {
                    initWebServer(path)
                }
                .disabled(serverstarted)
            }
        }
    }

    func initWebServer(_ path: String) {
        let server = GCDWebDAVServer(uploadDirectory: path)
        if server.start() {
            webdav = server
            serverstarted = true
            Alertinator.shared.alert(title: "Success!", body: "Enter \(webdav?.serverURL.absoluteString ?? "") in your webdav client")
        } else {
            Alertinator.shared.alert(title: "Error", body: "Failed to start server. Make sure the path is correct and you have the necessary permissions.")
        }
    }
}