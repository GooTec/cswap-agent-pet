// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChiikawaPet",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ChiikawaPet", targets: ["ChiikawaPet"])],
    targets: [
        .executableTarget(name: "ChiikawaPet", resources: [.process("Resources")]),
        .testTarget(name: "ChiikawaPetTests", dependencies: ["ChiikawaPet"])
    ]
)
