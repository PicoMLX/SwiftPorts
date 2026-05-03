// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SwiftGH",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "SwiftGHCore", targets: ["SwiftGHCore"]),
        .library(name: "SwiftGHCommand", targets: ["SwiftGHCommand"]),
        .executable(name: "gh", targets: ["gh"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser",
                 from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log",
                 from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-http-types",
                 from: "1.3.0"),
        // YAML trait pulls in `FileProvider<YAMLSnapshot>` for reading
        // ~/.config/gh/config.yml and hosts.yml later. CommandLineArguments
        // trait gives us a uniform precedence chain (CLI > env > file).
        .package(url: "https://github.com/apple/swift-configuration",
                 from: "1.2.0",
                 traits: [.defaults, "YAML", "CommandLineArguments"]),
        // swift-crypto exposes the same API as CryptoKit but works on Linux
        // too. Used by the future OAuth flow (PKCE = SHA-256 of a verifier).
        .package(url: "https://github.com/apple/swift-crypto",
                 from: "3.0.0"),
        // libyaml-backed YAML reader/writer. swift-configuration covers
        // the read side via a trait, but we also need to *write*
        // ~/.config/gh/config.yml and hosts.yml — Yams handles both
        // directions and is the de-facto Swift YAML library.
        .package(url: "https://github.com/jpsim/Yams",
                 from: "6.0.0"),
        // ZipKit lives next door under SwiftPorts. Wraps ZIPFoundation
        // for the operations zip(1) and unzip(1) need; same library
        // also powers `gh run view --log` and `gh run download --extract`.
        .package(path: "../ZipKit"),
    ],
    targets: [
        .target(
            name: "SwiftGHCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ZipKit", package: "ZipKit"),
            ],
            path: "Sources/SwiftGHCore"
        ),
        .target(
            name: "SwiftGHCommand",
            dependencies: [
                "SwiftGHCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/SwiftGHCommand"
        ),
        .executableTarget(
            name: "gh",
            dependencies: [
                "SwiftGHCommand",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/gh"
        ),
        .testTarget(
            name: "SwiftGHCoreTests",
            dependencies: ["SwiftGHCore"],
            path: "Tests/SwiftGHCoreTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "SwiftGHCommandTests",
            dependencies: ["SwiftGHCommand", "SwiftGHCore"],
            path: "Tests/SwiftGHCommandTests"
        ),
    ]
)
