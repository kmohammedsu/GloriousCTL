// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "GloriousCTL",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "GloriousCTL", targets: ["GloriousCTL"]),
    .executable(name: "gloriousctl-probe", targets: ["gloriousctl-probe"]),
    .executable(name: "gloriousctl-render", targets: ["gloriousctl-render"]),
    .executable(name: "gloriousctl-capture", targets: ["gloriousctl-capture"]),
    .library(name: "GloriousCore", targets: ["GloriousCore"]),
  ],
  targets: [
    .target(name: "GloriousCore"),
    .target(name: "GloriousUI", dependencies: ["GloriousCore"]),
    .executableTarget(
      name: "GloriousCTL",
      dependencies: ["GloriousCore", "GloriousUI"],
      resources: [.process("Resources")]),
    .executableTarget(name: "gloriousctl-probe", dependencies: ["GloriousCore"]),
    .executableTarget(name: "gloriousctl-render", dependencies: ["GloriousUI", "GloriousCore"]),
    .executableTarget(name: "gloriousctl-capture", dependencies: ["GloriousCore"]),
    .testTarget(name: "GloriousCoreTests", dependencies: ["GloriousCore"]),
    .testTarget(name: "GloriousUITests", dependencies: ["GloriousUI", "GloriousCore"]),
  ]
)
