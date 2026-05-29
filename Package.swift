// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "voq-mail",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoqMail", targets: ["VoqMail"])
    ],
    targets: [
        .executableTarget(name: "VoqMail")
    ]
)
