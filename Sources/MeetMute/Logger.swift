import Foundation

final class Logger {
    static let shared = Logger()

    enum Level: String {
        case info, warn, error
    }

    private let stdoutAttached: Bool

    private init() {
        stdoutAttached = isatty(STDOUT_FILENO) != 0
    }

    // Placeholder — full ring buffer + enabled flag land in M4.
    // In M1 this is a no-op unless the binary is launched from a terminal.
    func log(_ message: String, level: Level = .info) {
        guard stdoutAttached else { return }
        let ts = Self.timestamp()
        print("[\(ts)] [\(level.rawValue)] \(message)")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
