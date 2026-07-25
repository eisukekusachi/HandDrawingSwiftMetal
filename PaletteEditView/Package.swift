// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PaletteEditView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PaletteEditView",
            targets: ["PaletteEditView"]
        ),
    ],
    targets: [
        .target(
            name: "PaletteEditView",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PaletteEditViewTests",
            dependencies: ["PaletteEditView"]
        ),
    ]
)
