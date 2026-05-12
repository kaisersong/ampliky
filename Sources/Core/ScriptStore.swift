import Foundation

class ScriptStore {
    private let scriptsDir: URL

    init(scriptsDir: URL) {
        self.scriptsDir = scriptsDir
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
    }

    convenience init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.init(scriptsDir: home.appendingPathComponent(".ampliky/scripts"))
    }

    // Save a script and return its UUID
    func saveScript(content: String, name: String) -> String {
        let id = UUID().uuidString
        let filename = "\(id).js"
        let url = scriptsDir.appendingPathComponent(filename)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return filename
    }

    func loadScript(_ filename: String) -> String? {
        let url = scriptsDir.appendingPathComponent(filename)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func deleteScript(_ filename: String) {
        let url = scriptsDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    func listScripts() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: scriptsDir.path)) ?? [])
            .filter { $0.hasSuffix(".js") }
    }
}
