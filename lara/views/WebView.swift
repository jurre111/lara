import SwiftUI
import Foundation

struct WebView: View {
    @State private var serverstarted = false
    var body: some View {
        List {
            Section {
                Button(serverstarted ? "Running..." : "Start Web Server") {
                    initWebServer()
                }
                .disabled(serverstarted)
            }
        }
    }

    func initWebServer() {

        let webServer = GCDWebServer()

        webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
                return GCDWebServerDataResponse(html:"<html><body><p>Hello World</p></body></html>")
                
            })
            
        webServer.start(withPort: 8080, bonjourName: "GCD Web Server")
        serverstarted = true
        Alertinator.shared.alert(title: "Success!", body: "Visit \(webServer.serverURL) in your web browser")
    }
}