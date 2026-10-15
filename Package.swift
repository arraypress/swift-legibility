// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-legibility",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        // Whether drawn text can be read, measured on the pixels: where the
        // ink is, how it stands out from what touches it (WCAG), and whether
        // on-device text recognition reads it back. CoreGraphics + Vision.
        .library(name: "Legibility", targets: ["Legibility"]),
    ],
    targets: [
        .target(name: "Legibility"),
        .testTarget(name: "LegibilityTests", dependencies: ["Legibility"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
