// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VocaCore", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "VocaCore", targets: ["VocaCore"])], targets: [.target(name: "VocaCore"), .testTarget(name: "VocaCoreTests", dependencies: ["VocaCore"])])
