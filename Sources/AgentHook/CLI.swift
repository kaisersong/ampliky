import Foundation

@main
struct AmplikyCLI {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        guard let subcommand = args.first else {
            printUsage()
            return
        }

        let socketPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ampliky/ampliky.sock").path

        switch subcommand {
        case "run":
            let scriptCode = args.dropFirst().joined(separator: " ")
            // Wrap script as JSON string
            let encodedScript = scriptCode.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let request = """
            {"jsonrpc":"2.0","method":"run","params":{"script":"\(encodedScript)"},"id":1}
            """
            let response = sendToSocket(path: socketPath, message: request)
            print(response)

        case "exec":
            // Execute action by name (for convenience)
            let jsonString = args.dropFirst().joined(separator: " ")
            let request = """
            {"jsonrpc":"2.0","method":"exec","params":\(jsonString),"id":1}
            """
            let response = sendToSocket(path: socketPath, message: request)
            print(response)

        case "rule":
            let action = args.dropFirst().first
            switch action {
            case "list":
                let request = """
                {"jsonrpc":"2.0","method":"rule.list","params":{},"id":1}
                """
                let response = sendToSocket(path: socketPath, message: request)
                print(response)
            case "remove":
                let id = args.dropFirst().dropFirst().first ?? ""
                let request = """
                {"jsonrpc":"2.0","method":"rule.remove","params":{"id":"\(id)"},"id":1}
                """
                let response = sendToSocket(path: socketPath, message: request)
                print(response)
            default:
                printUsage()
            }

        case "context":
            let request = """
            {"jsonrpc":"2.0","method":"context","params":{},"id":1}
            """
            let response = sendToSocket(path: socketPath, message: request)
            print(response)

        default:
            printUsage()
        }
    }

    static func sendToSocket(path: String, message: String) -> String {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return "{\"error\":\"Failed to create socket\"}" }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        path.withCString { pathPtr in
            _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
                strcpy(dest, pathPtr)
            }
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                Darwin.connect(socket, rebound, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            close(socket)
            return "{\"error\":\"Failed to connect. Is ampliky daemon running?\"}"
        }

        message.withCString { msgPtr in
            _ = write(socket, msgPtr, strlen(msgPtr))
        }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, 4095)
        close(socket)

        guard bytesRead > 0 else { return "{\"error\":\"No response from daemon\"}" }
        buffer[bytesRead] = 0
        return String(cString: buffer)
    }

    static func printUsage() {
        print("""
        ampliky - AI-native macOS automation engine

        Usage:
          ampliky run '<script_js>'      Execute JavaScript directly
          ampliky exec '<action_json>'   Execute action by name
          ampliky rule list              List all rules
          ampliky rule remove <id>       Remove a rule
          ampliky context                Show current context (screens)

        Examples:
          ampliky run 'Ampliky.cursor.warpNext()'
          ampliky exec '{"name":"teleportCursor","params":{"to":"next_screen"}}'
          ampliky context
        """)
    }
}
