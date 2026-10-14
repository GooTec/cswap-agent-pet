// swift-tools-version: 6.0
import PackageDescription
import Foundation

let package = Package(
    name: "ChiikawaPet",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ChiikawaPet", targets: ["ChiikawaPet"])],
    targets: [
        .executableTarget(
            name: "ChiikawaPet",
            path: ".",
            exclude: ["build", "macos/Tests", "macos/Resources", "windows", "scripts", "README.md", "Launch.command"].filter {
                FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent().appendingPathComponent($0).path)
            },
            sources: ["macos/Sources/ChiikawaPet"],
            resources: [.process("assets")]
        ),
        .testTarget(
            name: "ChiikawaPetTests", dependencies: ["ChiikawaPet"],
            path: "macos/Tests/ChiikawaPetTests"
        )
    ]
)
