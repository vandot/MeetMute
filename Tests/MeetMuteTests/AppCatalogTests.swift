import XCTest
@testable import MeetMute

final class AppCatalogTests: XCTestCase {
    func testSupportedAppsIncludesTeamsNew() {
        let teams = supportedApps.first { $0.name == "Microsoft Teams" }
        XCTAssertNotNil(teams)
        XCTAssertTrue(teams!.bundleIdentifiers.contains("com.microsoft.teams2"))
        XCTAssertNil(teams!.windowMenuExcludePrefix,
                     "New Teams must not use the Window-menu switch path")
    }

    func testSupportedAppsIncludesTeamsClassic() {
        let classic = supportedApps.first { $0.name == "Microsoft Teams (Classic)" }
        XCTAssertNotNil(classic)
        XCTAssertEqual(classic!.windowMenuExcludePrefix, "Chat")
    }

    func testSlackUsesWindowTitlePrefix() {
        let slack = supportedApps.first { $0.name == "Slack" }
        XCTAssertNotNil(slack)
        XCTAssertEqual(slack!.windowTitlePrefix, "Huddle")
    }

    func testAllMeetingBundleIdsIsSetOfEveryId() {
        let expectedCount = supportedApps.reduce(0) { $0 + $1.bundleIdentifiers.count }
        XCTAssertEqual(allMeetingBundleIds.count, expectedCount)
        XCTAssertTrue(allMeetingBundleIds.contains("com.microsoft.teams2"))
        XCTAssertTrue(allMeetingBundleIds.contains("us.zoom.xos"))
    }

    func testBrowserAppsAreFlagged() {
        let safari = supportedApps.first { $0.name.contains("Safari") }
        XCTAssertNotNil(safari)
        XCTAssertTrue(safari!.isBrowserBased)

        let zoom = supportedApps.first { $0.name == "Zoom" }
        XCTAssertFalse(zoom!.isBrowserBased)
    }
}
