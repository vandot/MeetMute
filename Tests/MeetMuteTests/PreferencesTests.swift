import XCTest
@testable import MeetMute

final class PreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var prefs: Preferences!

    override func setUp() {
        super.setUp()
        suiteName = "com.meetmute.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        prefs = Preferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSelectedAppBundleIdDefaultsToNil() {
        XCTAssertNil(prefs.selectedAppBundleId)
    }

    func testSelectedAppBundleIdRoundTrip() {
        prefs.selectedAppBundleId = "com.microsoft.teams2"
        XCTAssertEqual(prefs.selectedAppBundleId, "com.microsoft.teams2")
    }

    func testSelectedAppBundleIdClearing() {
        prefs.selectedAppBundleId = "com.microsoft.teams2"
        prefs.selectedAppBundleId = nil
        XCTAssertNil(prefs.selectedAppBundleId)
    }

    func testHotkeyKeyCodeDefaultIsM() {
        // kVK_ANSI_M = 0x2E
        XCTAssertEqual(prefs.hotkeyKeyCode, 0x2E)
    }

    func testHotkeyModifiersDefaultIsCtrlOption() {
        // NSEvent.ModifierFlags raw for .control | .option
        let expected = NSEvent.ModifierFlags([.control, .option]).rawValue
        XCTAssertEqual(prefs.hotkeyModifiers, expected)
    }

    func testHotkeyHoldThresholdDefaultIs250() {
        XCTAssertEqual(prefs.hotkeyHoldThresholdMs, 250)
    }

    func testHotkeyRoundTrip() {
        prefs.hotkeyKeyCode = 0x23  // P
        let mods = NSEvent.ModifierFlags([.command, .shift]).rawValue
        prefs.hotkeyModifiers = mods
        XCTAssertEqual(prefs.hotkeyKeyCode, 0x23)
        XCTAssertEqual(prefs.hotkeyModifiers, mods)
    }
}
