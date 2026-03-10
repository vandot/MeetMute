import Cocoa

struct MeetingAppDefinition {
    let name: String
    let bundleIdentifiers: [String]
    let keyCode: CGKeyCode
    let modifierFlags: CGEventFlags
    // Browser-based apps (Chrome, Safari, etc.) are lower priority for auto-detect
    let isBrowserBased: Bool
    // Window title pattern to find (e.g. "Huddle" for Slack)
    let windowPattern: String?
    // Window title pattern to exclude - finds a window NOT matching this (e.g. for Teams meeting windows)
    let windowExcludePattern: String?

    init(name: String, bundleIdentifiers: [String], keyCode: CGKeyCode, modifierFlags: CGEventFlags, isBrowserBased: Bool = false, windowPattern: String? = nil, windowExcludePattern: String? = nil) {
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.isBrowserBased = isBrowserBased
        self.windowPattern = windowPattern
        self.windowExcludePattern = windowExcludePattern
    }
}

// Key codes reference:
// A = 0, S = 1, D = 2, F = 3, H = 4, G = 5, Z = 6, X = 7, C = 8, V = 9
// M = 46

let supportedApps: [MeetingAppDefinition] = [
    MeetingAppDefinition(
        name: "Zoom",
        bundleIdentifiers: ["us.zoom.xos"],
        keyCode: 0x00,  // A
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "Microsoft Teams",
        bundleIdentifiers: ["com.microsoft.teams", "com.microsoft.teams2"],
        keyCode: 0x2E,  // M
        modifierFlags: [.maskCommand, .maskShift],
        windowExcludePattern: "Microsoft Teams"
    ),
    MeetingAppDefinition(
        name: "Slack",
        bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
        keyCode: 0x31,  // Space
        modifierFlags: [.maskCommand, .maskShift],
        windowPattern: "Huddle"
    ),
    MeetingAppDefinition(
        name: "Webex",
        bundleIdentifiers: ["com.webex.meetingmanager", "Cisco-Systems.Spark"],
        keyCode: 0x2E,  // M
        modifierFlags: [.maskControl]
    ),
    MeetingAppDefinition(
        name: "Discord",
        bundleIdentifiers: ["com.hnc.Discord"],
        keyCode: 0x2E,  // M
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "FaceTime",
        bundleIdentifiers: ["com.apple.FaceTime"],
        keyCode: 0x2E,  // M
        modifierFlags: [.maskCommand, .maskShift]
    ),
    // Browser-based apps last (lower priority for auto-detect)
    MeetingAppDefinition(
        name: "Google Meet (Chrome)",
        bundleIdentifiers: ["com.google.Chrome"],
        keyCode: 0x02,  // D
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Arc)",
        bundleIdentifiers: ["company.thebrowser.Browser"],
        keyCode: 0x02,  // D
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Safari)",
        bundleIdentifiers: ["com.apple.Safari"],
        keyCode: 0x02,  // D
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Firefox)",
        bundleIdentifiers: ["org.mozilla.firefox"],
        keyCode: 0x02,  // D
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
]

struct RunningMeetingApp {
    let definition: MeetingAppDefinition
    let runningApp: NSRunningApplication
    let processName: String
}

func findRunningMeetingApps() -> [RunningMeetingApp] {
    let workspace = NSWorkspace.shared
    var results: [RunningMeetingApp] = []

    for appDef in supportedApps {
        for bundleId in appDef.bundleIdentifiers {
            let apps = workspace.runningApplications.filter { $0.bundleIdentifier == bundleId }
            for app in apps {
                if let name = app.localizedName {
                    results.append(RunningMeetingApp(
                        definition: appDef,
                        runningApp: app,
                        processName: name
                    ))
                }
            }
        }
    }

    return results
}

func appHasWindow(pid: pid_t, matching pattern: String) -> Bool {
    guard let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
        return false
    }
    for window in windowList {
        guard let windowPid = window[kCGWindowOwnerPID as String] as? pid_t,
              windowPid == pid,
              let windowName = window[kCGWindowName as String] as? String else {
            continue
        }
        if windowName.contains(pattern) {
            return true
        }
    }
    return false
}

func browserHasMeetTab(bundleId: String) -> Bool {
    let script: String
    switch bundleId {
    case "com.apple.Safari":
        script = """
        tell application "Safari"
            set foundMeet to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set foundMeet to true
                        exit repeat
                    end if
                end repeat
                if foundMeet then exit repeat
            end repeat
            return foundMeet
        end tell
        """
    case "com.google.Chrome":
        script = """
        tell application "Google Chrome"
            set foundMeet to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set foundMeet to true
                        exit repeat
                    end if
                end repeat
                if foundMeet then exit repeat
            end repeat
            return foundMeet
        end tell
        """
    case "company.thebrowser.Browser":
        script = """
        tell application "Arc"
            set foundMeet to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set foundMeet to true
                        exit repeat
                    end if
                end repeat
                if foundMeet then exit repeat
            end repeat
            return foundMeet
        end tell
        """
    default:
        return false  // Firefox etc. - can't check
    }

    var error: NSDictionary?
    let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
    if let result = result {
        return result.booleanValue
    }
    return false
}

func sendMuteKeystroke(to app: RunningMeetingApp) -> Bool {
    let escapedName = app.processName.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")

    var modifierParts: [String] = []
    if app.definition.modifierFlags.contains(.maskCommand) { modifierParts.append("command down") }
    if app.definition.modifierFlags.contains(.maskShift) { modifierParts.append("shift down") }
    if app.definition.modifierFlags.contains(.maskControl) { modifierParts.append("control down") }
    if app.definition.modifierFlags.contains(.maskAlternate) { modifierParts.append("option down") }

    let keyCodeInt = Int(app.definition.keyCode)
    let keystrokeCmd: String
    if modifierParts.isEmpty {
        keystrokeCmd = "key code \(keyCodeInt)"
    } else {
        keystrokeCmd = "key code \(keyCodeInt) using {\(modifierParts.joined(separator: ", "))}"
    }

    let script: String
    if app.definition.isBrowserBased {
        // For browser-based apps, find the Meet tab and switch to it first
        script = buildBrowserScript(
            browserName: escapedName,
            bundleId: app.runningApp.bundleIdentifier ?? "",
            keystrokeCmd: keystrokeCmd
        )
    } else if let windowPattern = app.definition.windowPattern {
        // Find a specific window (e.g. Slack Huddle) and raise it before sending keystroke
        // Also save/restore the original window if we're already in this app
        script = """
        set frontApp to path to frontmost application as text
        set frontIsTarget to (frontApp contains "\(escapedName)")
        tell application "\(escapedName)" to activate
        delay 0.3
        tell application "System Events"
            tell application process "\(escapedName)"
                -- Save the current front window before switching
                set origWindowName to ""
                if frontIsTarget and (count of windows) > 0 then
                    set origWindowName to name of front window
                end if

                -- Raise the specific window to front
                repeat with w in windows
                    if name of w contains "\(windowPattern)" then
                        perform action "AXRaise" of w
                        exit repeat
                    end if
                end repeat
            end tell
        end tell
        delay 0.2
        tell application "System Events"
            tell application process "\(escapedName)"
                \(keystrokeCmd)
            end tell
        end tell
        delay 0.1
        -- Restore original state
        if frontIsTarget and origWindowName is not "" then
            tell application "System Events"
                tell application process "\(escapedName)"
                    repeat with w in windows
                        if name of w is origWindowName then
                            perform action "AXRaise" of w
                            exit repeat
                        end if
                    end repeat
                end tell
            end tell
        else
            tell application frontApp to activate
        end if
        """
    } else if let excludePattern = app.definition.windowExcludePattern {
        // Find a window that does NOT match the exclude pattern (e.g. Teams meeting window)
        let escapedExclude = excludePattern.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        script = """
        set frontApp to path to frontmost application as text
        set frontIsTarget to (frontApp contains "\(escapedName)")
        tell application "\(escapedName)" to activate
        delay 0.3
        tell application "System Events"
            tell application process "\(escapedName)"
                -- Save the current front window before switching
                set origWindowName to ""
                if frontIsTarget and (count of windows) > 0 then
                    set origWindowName to name of front window
                end if

                -- Find a window that is NOT the main window (likely the meeting window)
                set foundMeeting to false
                repeat with w in windows
                    set wName to name of w
                    if wName does not contain "\(escapedExclude)" and wName is not "" then
                        perform action "AXRaise" of w
                        set foundMeeting to true
                        exit repeat
                    end if
                end repeat
            end tell
        end tell
        delay 0.2
        tell application "System Events"
            tell application process "\(escapedName)"
                \(keystrokeCmd)
            end tell
        end tell
        delay 0.1
        -- Restore original state
        if frontIsTarget and origWindowName is not "" then
            tell application "System Events"
                tell application process "\(escapedName)"
                    repeat with w in windows
                        if name of w is origWindowName then
                            perform action "AXRaise" of w
                            exit repeat
                        end if
                    end repeat
                end tell
            end tell
        else
            tell application frontApp to activate
        end if
        """
    } else {
        script = """
        set frontApp to path to frontmost application as text
        tell application "\(escapedName)" to activate
        delay 0.2
        tell application "System Events"
            tell application process "\(escapedName)"
                \(keystrokeCmd)
            end tell
        end tell
        delay 0.1
        tell application frontApp to activate
        """
    }

    var error: NSDictionary?
    let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
    return result != nil && error == nil
}

private func buildBrowserScript(browserName: String, bundleId: String, keystrokeCmd: String) -> String {
    if bundleId == "com.apple.Safari" {
        return """
        set frontApp to path to frontmost application as text
        set frontIsSafari to (frontApp contains "Safari")
        tell application "Safari"
            -- Save original window/tab if we're already in Safari
            set origWindow to missing value
            set origTab to missing value
            if frontIsSafari and (count of windows) > 0 then
                set origWindow to front window
                set origTab to current tab of origWindow
            end if

            set foundTab to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set current tab of w to t
                        set index of w to 1
                        activate
                        set foundTab to true
                        exit repeat
                    end if
                end repeat
                if foundTab then exit repeat
            end repeat
        end tell
        if foundTab then
            delay 0.2
            tell application "System Events"
                tell application process "Safari"
                    \(keystrokeCmd)
                end tell
            end tell
            delay 0.1
            -- Restore original state
            if frontIsSafari and origWindow is not missing value then
                tell application "Safari"
                    set current tab of origWindow to origTab
                    set index of origWindow to 1
                end tell
            else
                tell application frontApp to activate
            end if
        end if
        """
    } else if bundleId == "com.google.Chrome" {
        return """
        set frontApp to path to frontmost application as text
        set frontIsChrome to (frontApp contains "Chrome")
        tell application "Google Chrome"
            -- Save original window/tab if we're already in Chrome
            set origWindow to missing value
            set origTabIndex to 0
            if frontIsChrome and (count of windows) > 0 then
                set origWindow to front window
                set origTabIndex to active tab index of origWindow
            end if

            set foundTab to false
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        set active tab index of w to tabIndex
                        set index of w to 1
                        activate
                        set foundTab to true
                        exit repeat
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
                if foundTab then exit repeat
            end repeat
        end tell
        if foundTab then
            delay 0.2
            tell application "System Events"
                tell application process "Google Chrome"
                    \(keystrokeCmd)
                end tell
            end tell
            delay 0.1
            -- Restore original state
            if frontIsChrome and origWindow is not missing value then
                tell application "Google Chrome"
                    set active tab index of origWindow to origTabIndex
                    set index of origWindow to 1
                end tell
            else
                tell application frontApp to activate
            end if
        end if
        """
    } else if bundleId == "company.thebrowser.Browser" {
        return """
        set frontApp to path to frontmost application as text
        set frontIsArc to (frontApp contains "Arc")
        tell application "Arc"
            set origWindow to missing value
            set origTabId to missing value
            if frontIsArc and (count of windows) > 0 then
                set origWindow to front window
                try
                    set origTabId to id of active tab of origWindow
                end try
            end if

            set foundTab to false
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "meet.google.com" then
                        tell w
                            set foundTab to true
                            set index of w to 1
                            -- Activate the Meet tab
                        end tell
                        activate
                        exit repeat
                    end if
                end repeat
                if foundTab then exit repeat
            end repeat
        end tell
        if foundTab then
            delay 0.2
            tell application "System Events"
                tell application process "Arc"
                    \(keystrokeCmd)
                end tell
            end tell
            delay 0.1
            if frontIsArc and origWindow is not missing value then
                tell application "Arc"
                    set index of origWindow to 1
                end tell
            else
                tell application frontApp to activate
            end if
        end if
        """
    } else {
        // Firefox, etc. - no tab-level AppleScript support
        // Just activate and send (user needs Meet tab active)
        return """
        set frontApp to path to frontmost application as text
        tell application "\(browserName)" to activate
        delay 0.2
        tell application "System Events"
            tell application process "\(browserName)"
                \(keystrokeCmd)
            end tell
        end tell
        delay 0.1
        tell application frontApp to activate
        """
    }
}
