import XCTest
@testable import MeetMute

final class ScriptBuilderTests: XCTestCase {
    func testEscapeForAppleScriptEscapesBackslash() {
        XCTAssertEqual(ScriptBuilder.escape("a\\b"), "a\\\\b")
    }

    func testEscapeForAppleScriptEscapesDoubleQuote() {
        XCTAssertEqual(ScriptBuilder.escape("a\"b"), "a\\\"b")
    }

    func testEscapeForAppleScriptEscapesBoth() {
        XCTAssertEqual(ScriptBuilder.escape("\\\""), "\\\\\\\"")
    }

    func testKeystrokeStringNoModifiers() {
        let out = ScriptBuilder.keystroke(keyCode: 0x2E, modifierFlags: [])
        XCTAssertEqual(out, "key code 46")
    }

    func testKeystrokeStringSingleModifier() {
        let out = ScriptBuilder.keystroke(keyCode: 0x2E, modifierFlags: [.maskControl])
        XCTAssertEqual(out, "key code 46 using {control down}")
    }

    func testKeystrokeStringCommandShift() {
        let out = ScriptBuilder.keystroke(keyCode: 0x2E, modifierFlags: [.maskCommand, .maskShift])
        XCTAssertEqual(out, "key code 46 using {command down, shift down}")
    }

    func testKeystrokeStringAllModifiers() {
        let out = ScriptBuilder.keystroke(
            keyCode: 0x00,
            modifierFlags: [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        )
        XCTAssertEqual(out, "key code 0 using {command down, shift down, control down, option down}")
    }

    func testSubstituteReplacesAllTokens() {
        let template = "hello {{NAME}}, you are {{ROLE}}"
        let out = ScriptBuilder.substitute(template, values: ["NAME": "world", "ROLE": "dev"])
        XCTAssertEqual(out, "hello world, you are dev")
    }

    func testSubstituteEscapesValues() {
        let template = "name: {{NAME}}"
        let out = ScriptBuilder.substitute(template, values: ["NAME": "O\"Brien"])
        XCTAssertEqual(out, "name: O\\\"Brien")
    }
}
