// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "FileView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "FileView",
            targets: ["FileView"]
        ),
    ],
    targets: [
        .target(
            name: "FileView",
            path: "Sources",
            resources: [
                .process("FileView/Resources")
            ]
        ),
        .testTarget(
            name: "FileViewTests",
            dependencies: ["FileView"],
            path: "Tests"
        ),
    ]
)
