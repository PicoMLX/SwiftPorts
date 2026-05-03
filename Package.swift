// swift-tools-version:6.2
import PackageDescription

// SwiftPorts is a monorepo of pure-Swift, cross-platform
// reimplementations of standard CLI tools and SDK clients.
//
// Layout convention:
//   - A pure library port lives flat at `Sources/<Name>/`.
//   - A library + binary(ies) port lives under an umbrella folder
//     `Sources/<Umbrella>/` with these subfolders:
//       Lib/             — the SDK library target, named "<Umbrella>"
//       <X>Command/      — one library target per binary, holds the
//                          AsyncParsableCommand types (extendable by
//                          SwiftBash via cross-package import)
//       <x>/             — one executable target per binary, a four-line
//                          @main wrapper that delegates to <X>Command
//   - Library target names are PascalCase, executable target names are
//     lowercase and match the binary name.

let package = Package(
    name: "SwiftPorts",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        // ForgeKit — host-agnostic CLI plumbing (IO, Git, Secrets).
        .library(name: "ForgeKit", targets: ["ForgeKit"]),

        // ZipKit umbrella — Info-ZIP family.
        .library(name: "ZipKit", targets: ["ZipKit"]),
        .library(name: "ZipCommand", targets: ["ZipCommand"]),
        .library(name: "UnzipCommand", targets: ["UnzipCommand"]),
        .executable(name: "zip", targets: ["zip"]),
        .executable(name: "unzip", targets: ["unzip"]),

        // GitHub umbrella — gh(1) port.
        .library(name: "GitHub", targets: ["GitHub"]),
        .library(name: "GhCommand", targets: ["GhCommand"]),
        .executable(name: "gh", targets: ["gh"]),

        // GitLab umbrella — glab port.
        .library(name: "GitLab", targets: ["GitLab"]),
        .library(name: "GlabCommand", targets: ["GlabCommand"]),
        .executable(name: "glab", targets: ["glab"]),
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
        // MARK: ForgeKit (host-agnostic plumbing)
        .target(
            name: "ForgeKit",
            path: "Sources/ForgeKit"
        ),

        // MARK: ZipKit umbrella
        .target(
            name: "ZipKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            path: "Sources/ZipKit/Lib"
        ),
        .target(
            name: "ZipCommand",
            dependencies: [
                "ZipKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ZipKit/ZipCommand"
        ),
        .target(
            name: "UnzipCommand",
            dependencies: [
                "ZipKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ZipKit/UnzipCommand"
        ),
        .executableTarget(
            name: "zip",
            dependencies: ["ZipCommand"],
            path: "Sources/ZipKit/zip"
        ),
        .executableTarget(
            name: "unzip",
            dependencies: ["UnzipCommand"],
            path: "Sources/ZipKit/unzip"
        ),
        .testTarget(
            name: "ZipKitTests",
            dependencies: ["ZipKit"]
        ),
        .testTarget(
            name: "ZipTests",
            dependencies: ["ZipCommand", "ZipKit"]
        ),
        .testTarget(
            name: "UnzipTests",
            dependencies: ["UnzipCommand", "ZipKit"]
        ),

        // MARK: GitHub umbrella
        .target(
            name: "GitHub",
            dependencies: [
                "ForgeKit",
                "ZipKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/GitHub/Lib"
        ),
        .target(
            name: "GhCommand",
            dependencies: [
                "GitHub",
                "ForgeKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/GitHub/GhCommand"
        ),
        .executableTarget(
            name: "gh",
            dependencies: ["GhCommand"],
            path: "Sources/GitHub/gh"
        ),
        .testTarget(
            name: "GitHubTests",
            dependencies: ["GitHub", "GhCommand", "ForgeKit"],
            resources: [
                .copy("Fixtures"),
            ]
        ),

        // MARK: GitLab umbrella
        .target(
            name: "GitLab",
            dependencies: [
                "ForgeKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
            ],
            path: "Sources/GitLab/Lib"
        ),
        .target(
            name: "GlabCommand",
            dependencies: [
                "GitLab",
                "ForgeKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/GitLab/GlabCommand"
        ),
        .executableTarget(
            name: "glab",
            dependencies: ["GlabCommand"],
            path: "Sources/GitLab/glab"
        ),
        .testTarget(
            name: "GitLabTests",
            dependencies: ["GitLab", "GlabCommand", "ForgeKit"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
