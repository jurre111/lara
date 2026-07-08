import Network
import Foundation
import Combine

class http: ObservableObject {
    private var server: NWListener?
    private let queue = DispatchQueue(label: "http.queue")
    var port: UInt16 = 8080
    @Published var running = false

    init(port: UInt16) {
        self.port = port
        self.server = try! NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        server.newConnectionHandler = handleconnection
    }

    func changeport(to port: UInt16) {
        server.cancel()
        server = try! NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        server.newConnectionHandler = handleconnection
        self.port = port
    }

    func handleconnection(_ connection: NWConnection) {
        connection.start(queue: self.queue)
        laramgr.shared.log("New connection: \(connection.endpoint)")
        self.receive(from: connection)
    }

    func receive(from connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536
        ) { content, _, isComplete, error in

            if let error {
                laramgr.shared.log("Error: \(error)")
            } else if let content {
                laramgr.shared.log("Received request!")
                self.respond(on: connection)
            }

            if !isComplete {
                self.receive(from: connection)
            }
        }
    }


    func respond(on connection: NWConnection) {
        let html = "<html><body><h1>Hello, World!</h1></body></html>"


        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html\r
        Content-Length: \(html.utf8.count)\r
        \r
        \(html)
        """
        connection.send(
            content: response.data(using: .utf8),
            completion: .idempotent
        )
    }

    func start() {
        server?.start(queue: queue)
        DispatchQueue.main.async {
            self.running = true
        }
    }

    func stop() {
        server.cancel()
        DispatchQueue.main.async {
            self.running = false
        }
    }
}
