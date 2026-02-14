// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "RISC-V-Emulator",
    products: [
        .executable(name: "risc-emulator", targets: ["RISC-V-Emulator"])
    ],
    targets: [
        .executableTarget(
            name: "RISC-V-Emulator",
            path: "Sources"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["RISC-V-Emulator"],
            path: "Tests/IntegrationTests"
        )
    ]
)