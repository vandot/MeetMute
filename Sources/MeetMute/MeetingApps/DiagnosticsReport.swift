import Cocoa

enum DiagnosticsReport {
    static func build(hotkeyDisplay: String, selectedBundleId: String?) -> String {
        var lines: [String] = []
        lines.append("MeetMute \(appVersion()) | macOS \(osVersion()) | arch \(arch())")
        lines.append("Hotkey: \(hotkeyDisplay)")
        lines.append("Selected app: \(selectedBundleId ?? "auto-detect")")
        lines.append("")

        lines.append("Permissions")
        lines.append("  Accessibility: \(AXIsProcessTrusted() ? "granted" : "denied")")
        lines.append("  Automation:")
        lines.append("    System Events: \(probeSystemEvents())")
        for app in findRunningMeetingApps() {
            lines.append("    \(app.processName): \(probeAutomation(bundleId: app.runningApp.bundleIdentifier ?? ""))")
        }
        lines.append("")

        lines.append("Running meeting apps")
        for app in findRunningMeetingApps() {
            let pid = app.runningApp.processIdentifier
            lines.append("  - \(app.processName)  \(app.runningApp.bundleIdentifier ?? "?")  pid \(pid)")
            if app.definition.windowMenuExcludePrefix != nil {
                lines.append("      WindowMenu: \(fetchWindowMenu(bundleId: app.runningApp.bundleIdentifier ?? ""))")
            } else {
                lines.append("      Windows:    \(fetchWindowTitles(bundleId: app.runningApp.bundleIdentifier ?? ""))")
            }
        }
        lines.append("")

        lines.append("Last 100 log entries")
        let snap = Logger.shared.snapshot().suffix(100)
        for entry in snap {
            lines.append("  [\(Logger.format(entry.at))] [\(entry.level.rawValue)] \(entry.message)")
        }
        lines.append("")

        lines.append("NOTE: window titles may contain meeting names. Review before sharing publicly.")
        return lines.joined(separator: "\n")
    }

    private static func appVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static func arch() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    private static func probeSystemEvents() -> String {
        let script = "tell application \"System Events\" to return name of first process"
        var err: NSDictionary?
        _ = NSAppleScript(source: script)?.executeAndReturnError(&err)
        return interpretProbe(err)
    }

    private static func probeAutomation(bundleId: String) -> String {
        let script = "tell application id \"\(bundleId)\" to return name"
        var err: NSDictionary?
        _ = NSAppleScript(source: script)?.executeAndReturnError(&err)
        return interpretProbe(err)
    }

    private static func interpretProbe(_ err: NSDictionary?) -> String {
        guard let err = err else { return "granted" }
        let code = (err[NSAppleScript.errorNumber] as? Int) ?? 0
        if code == -1743 { return "denied" }
        return "unknown (err \(code))"
    }

    private static func fetchWindowTitles(bundleId: String) -> String {
        let script = "tell application \"System Events\" to tell (first process whose bundle identifier is \"\(bundleId)\") to get name of every window"
        return runListAppleScript(script)
    }

    private static func fetchWindowMenu(bundleId: String) -> String {
        let script = "tell application \"System Events\" to tell (first process whose bundle identifier is \"\(bundleId)\") to get name of every menu item of menu 1 of menu bar item \"Window\" of menu bar 1"
        return runListAppleScript(script)
    }

    private static func runListAppleScript(_ script: String) -> String {
        var err: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&err) else {
            return "<denied or unavailable>"
        }
        guard result.numberOfItems > 0 else { return "[]" }
        var items: [String] = []
        for i in 1...result.numberOfItems {
            if let str = result.atIndex(i)?.stringValue { items.append(str) }
        }
        return "[\(items.joined(separator: ", "))]"
    }
}
