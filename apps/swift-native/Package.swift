// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PureReader",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PureReader",
            targets: ["PureReader"]
        ),
        .executable(
            name: "PureReaderTests",
            targets: ["PureReaderTests"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "PureReaderCore",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "PureReaderNative",
            exclude: ["Resources/Info.plist", "Tests", "Sources/App"],
            sources: ["Sources/Models", "Sources/Services", "Sources/Localization", "Sources/ViewModels", "Sources/Parsers", "Sources/Rendering", "Sources/Views"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "PureReader",
            dependencies: ["PureReaderCore"],
            path: "PureReaderNative/Sources/App"
        ),
        .executableTarget(
            name: "PureReaderTests",
            dependencies: ["PureReaderCore"],
            path: "PureReaderNative/Tests",
            exclude: ["TestResources"]
        )
    ]
)
