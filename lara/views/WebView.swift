import SwiftUI
import Foundation

struct WebView: View {
    @State private var serverstarted = false
    @State private var path: String = "/"
    @State private var webdav: GCDWebDAVServer?
    @State private var url: URL?
    var body: some View {
        List {
            Section {
                TextField("Path", text: $path)
                Button(serverstarted && url != nil ? "Running on \(url!.absoluteString)" : "Start WebDAV Server") {
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
            url = webdav?.serverURL
            Alertinator.shared.alert(title: "Success!", body: "Enter \(url?.absoluteString ?? "") in your webdav client")
        } else {
            Alertinator.shared.alert(title: "Error", body: "Failed to start server. Make sure the path is correct and you have the necessary permissions.")
        }
    }
}