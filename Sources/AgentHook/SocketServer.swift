import Foundation

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
    private let socketPath: String
    private var listenSock: Int32 = -1
    private var handler: ((RPCRequest) -> Data)?

    init(socketPath: String? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.socketPath = socketPath ?? home.appendingPathComponent(".ampliky/ampliky.sock").path
    }

    func setHandler(_ handler: @escaping (RPCRequest) -> Data) {
        self.handler = handler
    }

    func start() {
        let dir = URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(atPath: socketPath)

        listenSock = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSock >= 0 else {
            print("[Ampliky] socket() failed: \(errno)")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { strcpy(&addr.sun_path.0, $0) }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listenSock, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bindResult == 0 else {
            print("[Ampliky] bind() failed: \(errno) — path: \(socketPath)")
            Darwin.close(listenSock)
            return
        }

        let chmodResult = Darwin.chmod(socketPath, 0o600)
        let listenResult = Darwin.listen(listenSock, 5)
        print("[Ampliky] socket created at \(socketPath), chmod=\(chmodResult), listen=\(listenResult)")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        if listenSock >= 0 {
            Darwin.close(listenSock)
            listenSock = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    private func acceptLoop() {
        while listenSock >= 0 {
            let clientSock = Darwin.accept(listenSock, nil, nil)
            guard clientSock >= 0 else { break }
            handleClient(clientSock)
        }
    }

    private func handleClient(_ clientSock: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = Darwin.recv(clientSock, &buffer, 65535, 0)
        guard bytesRead > 0 else {
            Darwin.close(clientSock)
            return
        }

        let data = Data(buffer[..<bytesRead])
        if let request = SocketProtocol.parseRequest(data), let handler = handler {
            let response = handler(request)
            response.withUnsafeBytes { ptr in
                _ = Darwin.send(clientSock, ptr.baseAddress, response.count, 0)
            }
        }
        Darwin.close(clientSock)
    }
}
