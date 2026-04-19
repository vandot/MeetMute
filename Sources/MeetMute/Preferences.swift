import Cocoa

final class Preferences {
    private let defaults: UserDefaults

    private enum Key {
        static let selectedAppBundleId = "SelectedMeetingAppBundleId"
        static let hotkeyKeyCode = "HotkeyKeyCode"
        static let hotkeyModifiers = "HotkeyModifiers"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedAppBundleId: String? {
        get { defaults.string(forKey: Key.selectedAppBundleId) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Key.selectedAppBundleId)
            } else {
                defaults.removeObject(forKey: Key.selectedAppBundleId)
            }
        }
    }

    var hotkeyKeyCode: UInt16 {
        get {
            if defaults.object(forKey: Key.hotkeyKeyCode) == nil { return 0x2E }
            return UInt16(defaults.integer(forKey: Key.hotkeyKeyCode))
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyKeyCode) }
    }

    var hotkeyModifiers: UInt {
        get {
            if defaults.object(forKey: Key.hotkeyModifiers) == nil {
                return NSEvent.ModifierFlags([.control, .option]).rawValue
            }
            let raw = defaults.integer(forKey: Key.hotkeyModifiers)
            return UInt(bitPattern: raw)
        }
        set { defaults.set(Int(bitPattern: newValue), forKey: Key.hotkeyModifiers) }
    }

}
