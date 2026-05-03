// swift-tools-version:6.2
import PackageDescription

// SwiftPorts is a monorepo of pure-Swift, cross-platform
// reimplementations of standard CLI tools and SDK clients. Each port
// lives in its own `Sources/<TargetName>/` directory but they all
// share one `Package.swift` and one git history.
//
// Today: ZipKit (the shared archive library), Zip + Unzip (CLI ports
// of zip(1) / unzip(1)), and GitHub (port of the gh CLI plus its API
// client). GitLab is planned to land next to GitHub.
//
// Naming convention:
//   - Library target: matches the upstream project / domain name.
//     `Zip`, `Unzip`, `ZipKit`, `GitHub`.
//   - Executable target: same as the binary name. Lowercase. To dodge
//     macOS's case-insensitive filesystem when an executable shares a
//     name with a library (e.g. `Zip` lib + `zip` exec), the exec
//     target is suffixed `Bin` and the binary name is set via the
//     product alias.

let package = Package(
    name: "SwiftPorts",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        // Shared archive library — used by Zip, Unzip, GitHub.
        .library(name: "ZipKit", targets: ["ZipKit"]),

        // Zip / Unzip — pure-Swift ports of the Info-ZIP CLIs.
        .library(name: "Zip", targets: ["Zip"]),
        .library(name: "Unzip", targets: ["Unzip"]),
        .executable(name: "zip", targets: ["ZipBin"]),
        .executable(name: "unzip", targets: ["UnzipBin"]),

        // GitHub — port of the gh(1) CLI + its API client.
        .library(name: "GitHub", targets: ["GitHub"]),
        .executable(name: "gh", targets: ["gh"]),
    ],
    dependencies: [
        // Apple / swiftlang
        .package(url: "https://github.com/apple/swift-argument-parser",
                 from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log",
                 from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-http-types",
                 from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-configuration",
                 from: "1.2.0",
                 traits: [.defaults, "YAML", "CommandLineArguments"]),
        .package(url: "https://github.com/apple/swift-crypto",
                 from: "3.0.0"),

        // Community
        .package(url: "https://github.com/jpsim/Yams",
                 from: "6.0.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation",
                 from: "0.9.19"),
    ],
    targets: [
        // MARK: ZipKit (shared archive library)
        .target(
            name: "ZipKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .testTarget(
            name: "ZipKitTests",
            dependencies: ["ZipKit"]
        ),

        // MARK: Zip (zip(1) port) — library + binary
        .target(
            name: "Zip",
            dependencies: [
                "ZipKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "ZipBin",
            dependencies: ["Zip"]
        ),
        .testTarget(
            name: "ZipTests",
            dependencies: ["Zip", "ZipKit"]
        ),

        // MARK: Unzip (unzip(1) port) — library + binary
        .target(
            name: "Unzip",
            dependencies: [
                "ZipKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "UnzipBin",
            dependencies: ["Unzip"]
        ),
        .testTarget(
            name: "UnzipTests",
            dependencies: ["Unzip", "ZipKit"]
        ),

        // MARK: GitHub (gh(1) port) — library + binary
        .target(
            name: "GitHub",
            dependencies: [
                "ZipKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "gh",
            dependencies: [
                "GitHub",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "GitHubTests",
            dependencies: ["GitHub"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
