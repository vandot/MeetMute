import Cocoa

private struct MeetTabCacheEntry {
    let result: Bool
    let at: Date
}

private var meetTabCache: [String: MeetTabCacheEntry] = [:]
private let meetTabCacheTTL: TimeInterval = 2.0
private let meetTabCacheQueue = DispatchQueue(label: "com.meetmute.meetTabCache")

func invalidateMeetTabCache(bundleId: String) {
    meetTabCacheQueue.sync { meetTabCache[bundleId] = nil }
}

func invalidateAllMeetTabCache() {
    meetTabCacheQueue.sync { meetTabCache.removeAll() }
}

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
    if let cached = meetTabCacheQueue.sync(execute: { meetTabCache[bundleId] }),
       Date().timeIntervalSince(cached.at) < meetTabCacheTTL {
        return cached.result
    }
    let fresh = browserHasMeetTabUncached(bundleId: bundleId)
    meetTabCacheQueue.sync {
        meetTabCache[bundleId] = MeetTabCacheEntry(result: fresh, at: Date())
    }
    return fresh
}

func browserHasMeetTabUncached(bundleId: String) -> Bool {
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
