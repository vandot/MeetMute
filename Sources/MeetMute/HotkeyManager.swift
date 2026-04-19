import Carbon.HIToolbox
import Cocoa

class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var onHotkeyPressed: (() -> Void)?

    private(set) var nsModifiers: NSEvent.ModifierFlags
    private(set) var keyCode: UInt16

    init(
        keyCode: UInt16 = UInt16(kVK_ANSI_M),
        modifiers: NSEvent.ModifierFlags = [.control, .option]
    ) {
        self.keyCode = keyCode
        self.nsModifiers = modifiers
    }

    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchesHotkey(event) {
                self.handleEvent(event)
                return nil
            }
            return event
        }
    }

    private func handleEvent(_ event: NSEvent) {
        guard matchesHotkey(event) else { return }
        if event.isARepeat { return }
        Logger.shared.log("hotkey pressed")
        onHotkeyPressed?()
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == keyCode && flags == nsModifiers
    }

    func unregister() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    deinit { unregister() }

    var hotkeyDisplayString: String {
        var parts: [String] = []
        if nsModifiers.contains(.control) { parts.append("\u{2303}") }
        if nsModifiers.contains(.option) { parts.append("\u{2325}") }
        if nsModifiers.contains(.shift) { parts.append("\u{21E7}") }
        if nsModifiers.contains(.command) { parts.append("\u{2318}") }

        let keyChar = Self.keyChar(for: keyCode)
        parts.append(keyChar)
        return parts.joined()
    }

    static func keyChar(for keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "\u{21A9}"
        case kVK_Tab: return "\u{21E5}"
        case kVK_Escape: return "\u{238B}"
        case kVK_Delete: return "\u{232B}"
        case kVK_LeftArrow: return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_UpArrow: return "\u{2191}"
        case kVK_DownArrow: return "\u{2193}"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "?"
        }
    }
}
