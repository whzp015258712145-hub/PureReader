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
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "PureReader",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "PureReaderNative",
            exclude: ["Resources/Info.plist", "Tests"],
            sources: ["Sources"],
            resources: [.process("Resources")]
        )
    ]
)

