import Foundation

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String

    init(level: LogLevel, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

enum LogLevel: String, Codable {
    case info = "INFO"
    case error = "ERROR"
    case debug = "DEBUG"
}

class Logger {
    static let shared = Logger()

    private let logFile: URL
    private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ampliky")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.logFile = dir.appendingPathComponent("logs.json")
        load()
    }

    func log(level: LogLevel, message: String) {
        let entry = LogEntry(level: level, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: logFile),
              let loaded = try? JSONDecoder().decode([LogEntry].self, from: data) else { return }
        entries = loaded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(entries)
        try? data?.write(to: logFile, options: .atomic)
    }
}
