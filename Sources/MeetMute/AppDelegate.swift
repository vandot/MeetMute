import Cocoa
import Carbon.HIToolbox
import ServiceManagement
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager?
    private let prefs = Preferences()
    private var lastActiveMeetingBundleId: String? = nil
    private var accessibilityPollTimer: Timer?
    private var hotkeyRecorderWindow: HotkeyRecorderWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (belt and suspenders with LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        setupAppActivationTracking()

        ScriptBuilder.verifyAllScriptsPresent()

        // Trigger system Accessibility permission dialog if not yet trusted
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Register hotkey now if already trusted, otherwise poll until granted
        if AXIsProcessTrusted() {
            setupHotkey()
        } else {
            accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.setupHotkey()
                    timer.invalidate()
                    self?.accessibilityPollTimer = nil
                }
            }
        }

        // Trigger Automation permission dialogs for running browsers upfront
        // so the user isn't surprised later. If denied, Meet tab detection
        // simply won't work and those browsers won't appear in the menu.
        requestBrowserAutomationPermissions()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func setupIcon() {
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "MeetMute")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // Toggle
        let toggleItem = NSMenuItem(
            title: "Toggle Mute",
            action: #selector(toggleMuteFromMenu),
            keyEquivalent: ""
        )
        toggleItem.target = self
        // Show hotkey hint in the menu item
        if let hotkeyHint = hotkeyManager?.hotkeyDisplayString {
            toggleItem.keyEquivalentModifierMask = []
            let attrTitle = NSMutableAttributedString(string: "Toggle Mute")
            attrTitle.append(NSAttributedString(
                string: "    \(hotkeyHint)",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.menuFont(ofSize: 13)]
            ))
            toggleItem.attributedTitle = attrTitle
        }
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Meeting apps section - only show running apps
        let runningApps = findRunningMeetingApps()

        var hasRunningApps = false
        for (index, appDef) in supportedApps.enumerated() {
            let isRunning = appDef.bundleIdentifiers.contains(where: { bundleId in
                runningApps.contains(where: { $0.runningApp.bundleIdentifier == bundleId })
            })
            guard isRunning else { continue }

            // For browser-based apps, check if they actually have a Meet tab
            if appDef.isBrowserBased {
                let hasMeet = appDef.bundleIdentifiers.contains(where: { browserHasMeetTab(bundleId: $0) })
                if !hasMeet { continue }
            }

            // Note: For apps with a window pattern (e.g. Slack Huddle), we can't reliably
            // check for the window without Screen Recording permission, so we show the app
            // whenever it's running. The window check happens when actually sending the keystroke.

            if !hasRunningApps {
                let headerItem = NSMenuItem(title: "Meeting App:", action: nil, keyEquivalent: "")
                headerItem.isEnabled = false
                menu.addItem(headerItem)

                // Auto-detect option
                let autoItem = NSMenuItem(title: "Auto-detect", action: #selector(selectAutoDetect), keyEquivalent: "")
                autoItem.target = self
                autoItem.state = prefs.selectedAppBundleId == nil ? .on : .off
                menu.addItem(autoItem)

                hasRunningApps = true
            }

            let title: String
            if appDef.isBrowserBased {
                title = "\(appDef.name) - Meet"
            } else {
                title = appDef.name
            }

            let isSelected: Bool = {
                guard let selected = self.prefs.selectedAppBundleId else { return false }
                return appDef.bundleIdentifiers.contains(selected)
            }()

            let item = NSMenuItem(title: title, action: #selector(selectApp(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = isSelected ? .on : .off
            menu.addItem(item)
        }

        if !hasRunningApps {
            let noAppsItem = NSMenuItem(title: "No meeting apps running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            menu.addItem(noAppsItem)
        }

        menu.addItem(NSMenuItem.separator())

        let coffeeItem = NSMenuItem(title: "Buy Me a Coffee", action: #selector(openBuyMeACoffee), keyEquivalent: "")
        coffeeItem.target = self
        menu.addItem(coffeeItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        let recorderItem = NSMenuItem(title: "Change Hotkey…", action: #selector(openHotkeyRecorder), keyEquivalent: "")
        recorderItem.target = self
        menu.addItem(recorderItem)

        // Version
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(title: "MeetMute v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MeetMute", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectAutoDetect() {
        prefs.selectedAppBundleId = nil
    }

    @objc private func selectApp(_ sender: NSMenuItem) {
        let def = supportedApps[sender.tag]
        // Store the first bundle ID (primary); subsequent IDs are aliases of the same app.
        prefs.selectedAppBundleId = def.bundleIdentifiers.first
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Silently ignore - user can toggle again
        }
    }

    @objc private func openBuyMeACoffee() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/vandot")!)
    }

    @objc private func openHotkeyRecorder() {
        let window = HotkeyRecorderWindow(
            initialKeyCode: prefs.hotkeyKeyCode,
            initialModifiers: NSEvent.ModifierFlags(rawValue: prefs.hotkeyModifiers)
        ) { [weak self] keyCode, modifiers in
            guard let self = self else { return }
            self.prefs.hotkeyKeyCode = keyCode
            self.prefs.hotkeyModifiers = modifiers.rawValue
            self.hotkeyManager?.unregister()
            self.setupHotkey()
        }
        hotkeyRecorderWindow = window
        window.showWindow(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - App Activation Tracking

    private func setupAppActivationTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier,
              allMeetingBundleIds.contains(bundleId) else { return }
        lastActiveMeetingBundleId = bundleId
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        invalidateMeetTabCache(bundleId: bundleId)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        let hk = HotkeyManager(
            keyCode: prefs.hotkeyKeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: prefs.hotkeyModifiers),
            holdThresholdMs: prefs.hotkeyHoldThresholdMs
        )
        hk.onHotkeyTap = { [weak self] in
            self?.toggleMute()
        }
        hk.onHotkeyHoldRelease = { [weak self] in
            self?.toggleMute()
        }
        hk.register()
        hotkeyManager = hk
    }

    // MARK: - Mute Toggle

    @objc private func toggleMuteFromMenu() {
        toggleMute()
    }

    private func toggleMute() {
        if !AXIsProcessTrusted() {
            showAccessibilityAlert()
            return
        }

        // Wait for modifier keys to be released so they don't interfere
        // with the keystroke we send to the target app
        waitForModifierRelease()

        let runningApps = findRunningMeetingApps()

        let target: RunningMeetingApp?
        if let bundleId = prefs.selectedAppBundleId {
            // User selected a specific app
            target = runningApps.first { app in
                app.definition.bundleIdentifiers.contains(bundleId)
            }
        } else if let lastBundleId = lastActiveMeetingBundleId,
                  let lastActive = runningApps.first(where: { $0.runningApp.bundleIdentifier == lastBundleId }) {
            // Auto-detect: prefer the most recently used meeting app
            target = lastActive
        } else {
            // Fallback: use first running meeting app
            target = runningApps.first
        }

        if let target = target {
            let reason: String
            if prefs.selectedAppBundleId != nil {
                reason = "user-pick"
            } else if lastActiveMeetingBundleId != nil {
                reason = "last-active"
            } else {
                reason = "fallback-first"
            }
            Logger.shared.log("mute target: \(target.runningApp.bundleIdentifier ?? "?") (\(reason))")
        } else {
            Logger.shared.log("mute target: none")
        }

        guard let targetApp = target else {
            showNoAppNotification()
            return
        }

        switch sendMuteKeystroke(to: targetApp) {
        case .success:
            break
        case .failure(let err):
            handleMuteFailure(err)
        }
    }

    private func handleMuteFailure(_ err: MuteError) {
        Logger.shared.log("mute failure: \(err)", level: .error)

        if case .automationDenied(_, let isSysEvents) = err, isSysEvents {
            showAutomationAlert(message: err.userMessage)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "MeetMute"
        content.body = err.userMessage
        let req = UNNotificationRequest(identifier: "mute-failure", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func showAutomationAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "MeetMute Needs Automation Permission"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
        }
    }

    private func showNoAppNotification() {
        let content = UNMutableNotificationContent()
        content.title = "MeetMute"
        content.body = "No meeting app detected. Open a meeting app or select one from the menu."

        let request = UNNotificationRequest(identifier: "no-app", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Modifier Keys

    private func waitForModifierRelease() {
        let start = Date()
        let timeout: TimeInterval = 2.0
        while Date().timeIntervalSince(start) < timeout {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
            if flags.intersection(modifiers).isEmpty {
                return
            }
            usleep(10_000)  // 10ms
        }
    }

    // MARK: - Browser Automation Permissions

    private func requestBrowserAutomationPermissions() {
        let browserApps: [(bundleId: String, appName: String)] = supportedApps
            .filter { $0.isBrowserBased }
            .flatMap { def in def.bundleIdentifiers.map { ($0, def.name.replacingOccurrences(of: "Google Meet (", with: "").replacingOccurrences(of: ")", with: "")) } }

        // System Events permission is needed for sending keystrokes
        let sysScript = "tell application \"System Events\" to return name of first process"
        var sysError: NSDictionary?
        NSAppleScript(source: sysScript)?.executeAndReturnError(&sysError)

        for browser in browserApps {
            // Only prompt if the browser is actually running
            let isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == browser.bundleId
            }
            guard isRunning else { continue }

            // A minimal AppleScript that triggers the Automation permission dialog
            let script = "tell application \"\(browser.appName)\" to return name of front window"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "MeetMute Needs Accessibility Permission"
        alert.informativeText = "MeetMute needs Accessibility access to send keyboard shortcuts to meeting apps and listen for global hotkeys.\n\nGo to System Settings > Privacy & Security > Accessibility and enable MeetMute."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
