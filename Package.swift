// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotesApp",
            targets: ["NotesApp"]
        ),
    ],
    dependencies: [
        // Add MLC-LLM or llama.cpp Swift bindings here when available
    ],
    targets: [
        .target(
            name: "NotesApp",
            dependencies: []
        ),
    ]
)

