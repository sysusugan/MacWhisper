// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PsstFree",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "PsstFree",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "PsstFree",
            exclude: [
                "Info.plist",
                "PsstFree.entitlements",
            ],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("NaturalLanguage"),
            ]
        ),
    ]
)
