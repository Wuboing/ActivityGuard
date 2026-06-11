// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ActivityGuard",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ActivityGuardCore"
        ),
        .executableTarget(
            name: "ActivityGuardApp",
            dependencies: ["ActivityGuardCore"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
