// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PaletteView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PaletteView",
            targets: ["PaletteView"]
        ),
    ],
    targets: [
        .target(
            name: "PaletteView"
        ),
    ]
)
