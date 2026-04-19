import Cocoa

enum ScriptKind {
    case activateAndSend
    case windowMenuSwitch
    case windowPatternRaise
    case browserMeetTab
    case browserMeetSimple
}

enum ScriptBuilder {
    static func escape(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func keystroke(keyCode: CGKeyCode, modifierFlags: CGEventFlags) -> String {
        var parts: [String] = []
        if modifierFlags.contains(.maskCommand) { parts.append("command down") }
        if modifierFlags.contains(.maskShift) { parts.append("shift down") }
        if modifierFlags.contains(.maskControl) { parts.append("control down") }
        if modifierFlags.contains(.maskAlternate) { parts.append("option down") }

        let codeInt = Int(keyCode)
        if parts.isEmpty {
            return "key code \(codeInt)"
        }
        return "key code \(codeInt) using {\(parts.joined(separator: ", "))}"
    }

    /// Replace `{{TOKEN}}` occurrences in template. Each value is
    /// AppleScript-escaped before substitution.
    static func substitute(_ template: String, values: [String: String]) -> String {
        var out = template
        for (key, value) in values {
            out = out.replacingOccurrences(of: "{{\(key)}}", with: escape(value))
        }
        return out
    }

    /// Loads a script resource by kind. Returns nil if the resource is missing.
    static func loadTemplate(_ kind: ScriptKind) -> String? {
        let filename: String
        switch kind {
        case .activateAndSend:     filename = "activate-and-send"
        case .windowMenuSwitch:    filename = "window-menu-switch"
        case .windowPatternRaise:  filename = "window-pattern-raise"
        case .browserMeetTab:      filename = "browser-meet-tab"
        case .browserMeetSimple:   filename = "browser-meet-simple"
        }
        // Scripts are copied into the main bundle by SwiftPM (.copy resource) and
        // by the Makefile; look inside the "Scripts" subdirectory.
        // Bundle.module is unavailable for executable targets — use Bundle.main.
        guard let url = Bundle.main.url(
            forResource: filename,
            withExtension: "applescript",
            subdirectory: "Scripts"
        ) else {
            Logger.shared.log("missing script resource: \(filename).applescript", level: .error)
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Sanity check run at startup to log any missing script resources.
    static func verifyAllScriptsPresent() {
        let kinds: [ScriptKind] = [
            .activateAndSend, .windowMenuSwitch, .windowPatternRaise,
            .browserMeetTab, .browserMeetSimple
        ]
        for kind in kinds {
            _ = loadTemplate(kind)
        }
    }
}
