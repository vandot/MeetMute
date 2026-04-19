// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeetMute",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeetMute",
            path: "Sources/MeetMute",
            resources: [
                .copy("../../Resources/Scripts")
            ],
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "MeetMuteTests",
            dependencies: ["MeetMute"],
            path: "Tests/MeetMuteTests"
        )
    ]
)
