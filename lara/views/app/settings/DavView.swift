import SwiftUI

struct DavView: View {
    @EnvironmentObject var server: http
    var body: some View {
        Section {
            TextField("Port", text: Binding(
                get: { String(server.port) },
                set: { server.changeport(to: UInt16($0) ?? 8080) }
            ))
                .disabled(server.running)
                .keyboardType(.numberPad)
            Button(server.running? "Stop" : "Start") {
                if server.running {
                    server.stop()
                } else {
                    server.start()
                }
            }
        } footer: {
            Text("Configure a simple http server on a chosen port")
        }
    }
}