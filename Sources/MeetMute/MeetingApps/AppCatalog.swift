import Cocoa

struct MeetingAppDefinition {
    let name: String
    let bundleIdentifiers: [String]
    let keyCode: CGKeyCode
    let modifierFlags: CGEventFlags
    let isBrowserBased: Bool
    let windowTitlePrefix: String?
    let windowMenuExcludePrefix: String?

    init(
        name: String,
        bundleIdentifiers: [String],
        keyCode: CGKeyCode,
        modifierFlags: CGEventFlags,
        isBrowserBased: Bool = false,
        windowTitlePrefix: String? = nil,
        windowMenuExcludePrefix: String? = nil
    ) {
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.isBrowserBased = isBrowserBased
        self.windowTitlePrefix = windowTitlePrefix
        self.windowMenuExcludePrefix = windowMenuExcludePrefix
    }
}

// Key codes: A = 0, S = 1, D = 2, H = 4, G = 5, Z = 6, X = 7, C = 8, V = 9, M = 46, P = 35
let supportedApps: [MeetingAppDefinition] = [
    MeetingAppDefinition(
        name: "Zoom",
        bundleIdentifiers: ["us.zoom.xos"],
        keyCode: 0x00,
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "Microsoft Teams",
        bundleIdentifiers: ["com.microsoft.teams2"],
        keyCode: 0x2E,
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "Microsoft Teams (Classic)",
        bundleIdentifiers: ["com.microsoft.teams"],
        keyCode: 0x2E,
        modifierFlags: [.maskCommand, .maskShift],
        windowMenuExcludePrefix: "Chat"
    ),
    MeetingAppDefinition(
        name: "Slack",
        bundleIdentifiers: ["com.tinyspeck.slackmacgap"],
        keyCode: 0x31,
        modifierFlags: [.maskCommand, .maskShift],
        windowTitlePrefix: "Huddle"
    ),
    MeetingAppDefinition(
        name: "Webex",
        bundleIdentifiers: ["com.webex.meetingmanager", "Cisco-Systems.Spark"],
        keyCode: 0x2E,
        modifierFlags: [.maskControl]
    ),
    MeetingAppDefinition(
        name: "Discord",
        bundleIdentifiers: ["com.hnc.Discord"],
        keyCode: 0x2E,
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "FaceTime",
        bundleIdentifiers: ["com.apple.FaceTime"],
        keyCode: 0x2E,
        modifierFlags: [.maskCommand, .maskShift]
    ),
    MeetingAppDefinition(
        name: "Google Meet (Chrome)",
        bundleIdentifiers: ["com.google.Chrome"],
        keyCode: 0x02,
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Arc)",
        bundleIdentifiers: ["company.thebrowser.Browser"],
        keyCode: 0x02,
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Safari)",
        bundleIdentifiers: ["com.apple.Safari"],
        keyCode: 0x02,
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
    MeetingAppDefinition(
        name: "Google Meet (Firefox)",
        bundleIdentifiers: ["org.mozilla.firefox"],
        keyCode: 0x02,
        modifierFlags: [.maskCommand],
        isBrowserBased: true
    ),
]

let allMeetingBundleIds: Set<String> = Set(supportedApps.flatMap { $0.bundleIdentifiers })
