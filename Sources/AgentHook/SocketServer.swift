import Foundation
import Network

struct RPCRequest {
    let method: String
    let params: [String: Any]
    let id: Int
}

enum SocketProtocol {
    static func parseRequest(_ data: Data) -> RPCRequest? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard obj["jsonrpc"] as? String == "2.0" else { return nil }
        guard let method = obj["method"] as? String else { return nil }
        guard let id = obj["id"] as? Int else { return nil }
        let params = obj["params"] as? [String: Any] ?? [:]
        return RPCRequest(method: method, params: params, id: id)
    }

    static func successResponse(id: Int, result: [String: Any]) -> Data {
        let obj: [String: Any] = ["jsonrpc": "2.0", "id": id, "result": result]
        return try! JSONSerialization.data(withJSONObject: obj)
    }

    static func errorResponse(id: Int, code: Int, message: String) -> Data {
        let obj: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": code, "message": message]
        ]
        return try! JSONSerialization.data(withJSONObject: obj)
    }
}

class SocketServer {
    private let socketPath: URL
    private var listener: NWListener?
    private var handler: ((RPCRequest) -> Data)?

    init(socketPath: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.socketPath = socketPath ?? home.appendingPathComponent(".ampliky/ampliky.sock")
    }

    func setHandler(_ handler: @escaping (RPCRequest) -> Data) {
        self.handler = handler
    }

    func start() throws {
        let existing = socketPath.path
        try? FileManager.default.removeItem(atPath: existing)

        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: 0)!)

        // For Unix domain socket, use a different approach
        // NWListener with .tcp requires a port, not a path.
        // We'll use the classic Darwin socket approach for Unix sockets.
        startUnixSocket(path: existing)
    }

    private func startUnixSocket(path: String) {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        path.withCString { pathPtr in
            _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
                strcpy(dest, pathPtr)
            }
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        guard withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                bind(sock, rebound, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        } == 0 else {
            close(sock)
            return
        }
        chmod(path, 0o600)
        listen(sock, 5)

        // Accept connections on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while let s = self {
                let clientSock = accept(sock, nil, nil)
                guard clientSock >= 0 else { break }
                s.handleClientSocket(clientSock)
            }
        }
        listener = nil // not using NWListener
    }

    private func handleClientSocket(_ clientSock: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = recv(clientSock, &buffer, 65535, 0)
        guard bytesRead > 0 else {
            close(clientSock)
            return
        }

        let data = Data(buffer[..<bytesRead])
        if let request = SocketProtocol.parseRequest(data), let handler = handler {
            let response = handler(request)
            _ = response.withUnsafeBytes { ptr in
                send(clientSock, ptr.baseAddress, response.count, 0)
            }
        }
        close(clientSock)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(at: socketPath)
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let data = data, error == nil else { return }
            if let request = SocketProtocol.parseRequest(data), let handler = self?.handler {
                let response = handler(request)
                conn.send(content: response, completion: .contentProcessed { _ in })
            }
            self?.handleConnection(conn)
        }
    }
}
