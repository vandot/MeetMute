// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeetMute",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeetMute",
            path: "Sources/MeetMute",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
