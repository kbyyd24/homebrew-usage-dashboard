// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UsageDashboard",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UsageDashCore"),
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
