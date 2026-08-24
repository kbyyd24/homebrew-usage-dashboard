// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UsageDash",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UsageDashCore"),
        .executableTarget(
            name: "UsageDash",
            dependencies: ["UsageDashCore"],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .testTarget(
            name: "UsageDashTests",
            dependencies: ["UsageDashCore", "UsageDash"],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
    ]
)
