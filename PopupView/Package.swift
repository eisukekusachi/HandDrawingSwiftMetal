// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PopupView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PopupView",
            targets: ["PopupView"]
        ),
    ],
    targets: [
        .target(
            name: "PopupView"
        ),
        .testTarget(
            name: "PopupViewTests",
            dependencies: ["PopupView"]
        ),
    ]
)
