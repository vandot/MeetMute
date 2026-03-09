import Carbon.HIToolbox
import Cocoa

class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onHotkeyPressed: (() -> Void)?

    // Default: Ctrl+Option+M
    private(set) var nsModifiers: NSEvent.ModifierFlags = [.control, .option]
    private(set) var keyCode: UInt16 = UInt16(kVK_ANSI_M)

    func register() {
        // Monitor key events when app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Monitor key events when app IS focused (e.g., menu open)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event) == true {
                self?.onHotkeyPressed?()
                return nil  // consume the event
            }
            return event
        }

    }

    private func handleKeyEvent(_ event: NSEvent) {
        if matchesHotkey(event) {
            onHotkeyPressed?()
        }
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && flags == nsModifiers
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        unregister()
    }

    var hotkeyDisplayString: String {
        var parts: [String] = []
        if nsModifiers.contains(.control) { parts.append("\u{2303}") }
        if nsModifiers.contains(.option) { parts.append("\u{2325}") }
        if nsModifiers.contains(.shift) { parts.append("\u{21E7}") }
        if nsModifiers.contains(.command) { parts.append("\u{2318}") }

        let keyChar: String
        switch Int(keyCode) {
        case kVK_ANSI_M: keyChar = "M"
        case kVK_ANSI_A: keyChar = "A"
        case kVK_ANSI_D: keyChar = "D"
        default: keyChar = "?"
        }
        parts.append(keyChar)
        return parts.joined()
    }
}
