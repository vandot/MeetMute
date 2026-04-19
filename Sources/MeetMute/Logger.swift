import Foundation

final class Logger {
    static let shared = Logger()

    enum Level: String {
        case info, warn, error
    }

    struct Entry {
        let at: Date
        let level: Level
        let message: String
    }

    private(set) var enabled: Bool = false
    private var ring: [Entry] = []
    private let cap = 500
    private let queue = DispatchQueue(label: "com.meetmute.logger")
    private let stdoutAttached: Bool

    private init() {
        stdoutAttached = isatty(STDOUT_FILENO) != 0
    }

    func setEnabled(_ on: Bool) {
        queue.sync { self.enabled = on }
    }

    func log(_ message: String, level: Level = .info) {
        let entry = Entry(at: Date(), level: level, message: message)
        queue.sync {
            if self.enabled {
                self.ring.append(entry)
                if self.ring.count > self.cap {
                    self.ring.removeFirst(self.ring.count - self.cap)
                }
            }
            if self.stdoutAttached {
                print("[\(Self.format(entry.at))] [\(entry.level.rawValue)] \(entry.message)")
            }
        }
    }

    func snapshot() -> [Entry] {
        return queue.sync { self.ring }
    }

    func clear() {
        queue.sync { self.ring.removeAll() }
    }

    static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: date)
    }
}
