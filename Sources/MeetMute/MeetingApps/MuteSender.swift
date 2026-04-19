import Cocoa

enum MuteError: Error {
    case automationDenied(appName: String, isSystemEvents: Bool)
    case appNotRunning(appName: String)
    case scriptFailed(code: Int, message: String)

    var userMessage: String {
        switch self {
        case .automationDenied(let name, let sysEvents):
            if sysEvents {
                return "MeetMute needs Automation access to System Events. Enable it in Privacy & Security → Automation."
            }
            return "Enable MeetMute → \(name) in Privacy & Security → Automation."
        case .appNotRunning(let name):
            return "\(name) isn't running."
        case .scriptFailed(_, let message):
            return "Mute failed: \(message)"
        }
    }
}

private func mapAppleScriptError(_ error: NSDictionary, appName: String) -> MuteError {
    let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
    let message = (error[NSAppleScript.errorMessage] as? String) ?? "unknown error"
    switch code {
    case -1743:
        let isSysEvents = message.contains("System Events")
        return .automationDenied(appName: appName, isSystemEvents: isSysEvents)
    case -600:
        return .appNotRunning(appName: appName)
    default:
        return .scriptFailed(code: code, message: message)
    }
}

func sendMuteKeystroke(to app: RunningMeetingApp) -> Result<Void, MuteError> {
    let def = app.definition
    let bundleId = app.runningApp.bundleIdentifier ?? ""
    let keystroke = ScriptBuilder.keystroke(keyCode: def.keyCode, modifierFlags: def.modifierFlags)

    let template: String?
    var values: [String: String]

    if def.isBrowserBased {
        return sendBrowserKeystroke(
            bundleId: bundleId, appName: app.processName, keystroke: keystroke
        )
    } else if let excludePrefix = def.windowMenuExcludePrefix {
        template = ScriptBuilder.loadTemplate(.windowMenuSwitch)
        values = [
            "BUNDLE_ID": bundleId,
            "APP_NAME": app.processName,
            "EXCLUDE_PREFIX": excludePrefix,
            "KEYSTROKE": keystroke
        ]
    } else if let windowPrefix = def.windowTitlePrefix {
        template = ScriptBuilder.loadTemplate(.windowPatternRaise)
        values = [
            "BUNDLE_ID": bundleId,
            "APP_NAME": app.processName,
            "WINDOW_PREFIX": windowPrefix,
            "KEYSTROKE": keystroke
        ]
    } else {
        template = ScriptBuilder.loadTemplate(.activateAndSend)
        values = [
            "BUNDLE_ID": bundleId,
            "KEYSTROKE": keystroke
        ]
    }

    // KEYSTROKE is already a well-formed AppleScript fragment — do NOT escape it.
    // Accomplish this by substituting KEYSTROKE last, after the other (escaped)
    // tokens. We substitute KEYSTROKE verbatim using plain string replacement.
    guard let rawTemplate = template else {
        Logger.shared.log("mute failed: missing script resource for \(app.processName)", level: .error)
        return .failure(.scriptFailed(code: 0, message: "missing script resource"))
    }

    let withEscaped = ScriptBuilder.substitute(
        rawTemplate,
        values: values.filter { $0.key != "KEYSTROKE" }
    )
    let final = withEscaped.replacingOccurrences(of: "{{KEYSTROKE}}", with: keystroke)

    Logger.shared.log("mute dispatch: \(app.processName) (\(bundleId))")

    var error: NSDictionary?
    let result = NSAppleScript(source: final)?.executeAndReturnError(&error)
    if let error = error {
        Logger.shared.log("mute error: \(error)", level: .error)
        return .failure(mapAppleScriptError(error, appName: app.processName))
    }
    guard result != nil else {
        return .failure(.scriptFailed(code: 0, message: "script compilation failed"))
    }
    return .success(())
}

private func sendBrowserKeystroke(bundleId: String, appName: String, keystroke: String) -> Result<Void, MuteError> {
    let tabSwitchBlock: String
    let restoreBlock: String
    let template: ScriptKind

    switch bundleId {
    case "com.apple.Safari":
        template = .browserMeetTab
        tabSwitchBlock = """
        tell application "Safari"
            set origWindow to missing value
            set origTab to missing value
            if frontIsBrowser and (count of windows) > 0 then
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
        """
        restoreBlock = """
        if frontIsBrowser and origWindow is not missing value then
            tell application "Safari"
                set current tab of origWindow to origTab
                set index of origWindow to 1
            end tell
        else
            tell application frontApp to activate
        end if
        """
    case "com.google.Chrome":
        template = .browserMeetTab
        tabSwitchBlock = """
        tell application "Google Chrome"
            set origWindow to missing value
            set origTabIndex to 0
            if frontIsBrowser and (count of windows) > 0 then
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
        """
        restoreBlock = """
        if frontIsBrowser and origWindow is not missing value then
            tell application "Google Chrome"
                set active tab index of origWindow to origTabIndex
                set index of origWindow to 1
            end tell
        else
            tell application frontApp to activate
        end if
        """
    case "company.thebrowser.Browser":
        template = .browserMeetTab
        tabSwitchBlock = """
        tell application "Arc"
            set origWindow to missing value
            set origTabId to missing value
            if frontIsBrowser and (count of windows) > 0 then
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
                        end tell
                        activate
                        exit repeat
                    end if
                end repeat
                if foundTab then exit repeat
            end repeat
        end tell
        """
        restoreBlock = """
        if frontIsBrowser and origWindow is not missing value then
            tell application "Arc"
                set index of origWindow to 1
            end tell
        else
            tell application frontApp to activate
        end if
        """
    default:
        // Firefox — no tab AppleScript support
        guard let rawTemplate = ScriptBuilder.loadTemplate(.browserMeetSimple) else {
            return .failure(.scriptFailed(code: 0, message: "missing script resource"))
        }
        let withEscaped = ScriptBuilder.substitute(rawTemplate, values: ["APP_NAME": appName])
        let final = withEscaped.replacingOccurrences(of: "{{KEYSTROKE}}", with: keystroke)
        var error: NSDictionary?
        let result = NSAppleScript(source: final)?.executeAndReturnError(&error)
        if let error = error {
            return .failure(mapAppleScriptError(error, appName: appName))
        }
        guard result != nil else {
            return .failure(.scriptFailed(code: 0, message: "script compilation failed"))
        }
        return .success(())
    }

    guard let rawTemplate = ScriptBuilder.loadTemplate(template) else {
        return .failure(.scriptFailed(code: 0, message: "missing script resource"))
    }
    // Escape only APP_NAME; the tab/restore blocks are pre-built AppleScript fragments.
    let withEscaped = ScriptBuilder.substitute(rawTemplate, values: ["APP_NAME": appName])
    let final = withEscaped
        .replacingOccurrences(of: "{{TAB_SWITCH_BLOCK}}", with: tabSwitchBlock)
        .replacingOccurrences(of: "{{RESTORE_BLOCK}}", with: restoreBlock)
        .replacingOccurrences(of: "{{KEYSTROKE}}", with: keystroke)

    var error: NSDictionary?
    let result = NSAppleScript(source: final)?.executeAndReturnError(&error)
    if let error = error {
        return .failure(mapAppleScriptError(error, appName: appName))
    }
    guard result != nil else {
        return .failure(.scriptFailed(code: 0, message: "script compilation failed"))
    }
    return .success(())
}
