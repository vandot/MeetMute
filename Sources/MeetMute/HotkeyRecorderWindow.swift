import Cocoa
import Carbon.HIToolbox

final class HotkeyRecorderWindow: NSWindowController {
    private let onSave: (UInt16, NSEvent.ModifierFlags) -> Void

    private var currentKeyCode: UInt16
    private var currentModifiers: NSEvent.ModifierFlags
    private var comboLabel: NSTextField!
    private var monitor: Any?

    init(
        initialKeyCode: UInt16,
        initialModifiers: NSEvent.ModifierFlags,
        onSave: @escaping (UInt16, NSEvent.ModifierFlags) -> Void
    ) {
        self.onSave = onSave
        self.currentKeyCode = initialKeyCode
        self.currentModifiers = initialModifiers

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Record Hotkey"
        panel.isFloatingPanel = true
        panel.center()
        super.init(window: panel)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let prompt = NSTextField(labelWithString: "Press a shortcut")
        prompt.alignment = .center
        prompt.frame = NSRect(x: 20, y: 110, width: 280, height: 20)
        content.addSubview(prompt)

        comboLabel = NSTextField(labelWithString: currentDisplay())
        comboLabel.alignment = .center
        comboLabel.font = NSFont.systemFont(ofSize: 20, weight: .medium)
        comboLabel.frame = NSRect(x: 20, y: 70, width: 280, height: 30)
        content.addSubview(comboLabel)

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetTapped))
        reset.frame = NSRect(x: 20, y: 20, width: 80, height: 28)
        content.addSubview(reset)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 140, y: 20, width: 80, height: 28)
        content.addSubview(cancel)

        let save = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 220, y: 20, width: 80, height: 28)
        content.addSubview(save)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        attachMonitor()
    }

    private func attachMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let meaningful: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let mods = flags.intersection(meaningful)
            if mods.isEmpty { return nil }
            self.currentKeyCode = event.keyCode
            self.currentModifiers = mods
            self.comboLabel.stringValue = self.currentDisplay()
            return nil
        }
    }

    private func detachMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func currentDisplay() -> String {
        var parts: [String] = []
        if currentModifiers.contains(.control) { parts.append("\u{2303}") }
        if currentModifiers.contains(.option) { parts.append("\u{2325}") }
        if currentModifiers.contains(.shift) { parts.append("\u{21E7}") }
        if currentModifiers.contains(.command) { parts.append("\u{2318}") }
        parts.append(HotkeyManager.keyChar(for: currentKeyCode))
        return parts.joined()
    }

    @objc private func resetTapped() {
        currentKeyCode = UInt16(kVK_ANSI_M)
        currentModifiers = [.control, .option]
        comboLabel.stringValue = currentDisplay()
    }

    @objc private func cancelTapped() {
        detachMonitor()
        close()
    }

    @objc private func saveTapped() {
        detachMonitor()
        onSave(currentKeyCode, currentModifiers)
        close()
    }
}
