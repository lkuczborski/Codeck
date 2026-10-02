// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Codeck",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Codeck", targets: ["Codeck"]),
        .executable(name: "codeck-mcp", targets: ["CodeckMCP"]),
        .library(name: "CodeckCore", targets: ["CodeckCore"]),
    ],
    targets: [
        .target(name: "CodeckCore"),
        .target(name: "CodeckRuntime", dependencies: ["CodeckCore"]),
        .executableTarget(name: "Codeck", dependencies: ["CodeckCore", "CodeckRuntime"]),
        .executableTarget(name: "CodeckMCP", dependencies: ["CodeckCore", "CodeckRuntime"]),
        .testTarget(name: "CodeckTests", dependencies: ["Codeck", "CodeckCore", "CodeckRuntime", "CodeckMCP"]),
    ]
)
