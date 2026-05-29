// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CatWalking",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CatWalking",
            targets: ["CatWalking"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CatWalking",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
