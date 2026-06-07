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
    .executableTarget(name: "Codeck", dependencies: ["CodeckCore"]),
    .executableTarget(name: "CodeckMCP", dependencies: ["CodeckCore"]),
    .testTarget(name: "CodeckTests", dependencies: ["Codeck", "CodeckCore"]),
  ]
)
