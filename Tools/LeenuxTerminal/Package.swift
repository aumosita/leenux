// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LeenuxTerminal",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "leenux-terminal", targets: ["LeenuxTerminal"])
    ],
    targets: [
        .systemLibrary(
            name: "CSDL2",
            pkgConfig: "sdl2",
            providers: [
                .brew(["sdl2"])
            ]
        ),
        .executableTarget(
            name: "LeenuxTerminal",
            dependencies: ["CSDL2"]
        )
    ]
)
