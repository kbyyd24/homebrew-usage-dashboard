// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UsageDashboard",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
    ],
    targets: [
        .target(
            name: "UsageDashCore",
            dependencies: ["Yams"]
        ),
        .executableTarget(
            name: "UsageDashboard",
            dependencies: ["UsageDashCore"],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .testTarget(
            name: "UsageDashboardTests",
            dependencies: ["UsageDashCore", "UsageDashboard"],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
    ]
)
