// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Codeck",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Codeck", targets: ["Codeck"])
  ],
  targets: [
    .executableTarget(name: "Codeck"),
    .testTarget(name: "CodeckTests", dependencies: ["Codeck"])
  ]
)
