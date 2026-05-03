# Agent instructions — SwiftPorts

A monorepo of pure-Swift, cross-platform reimplementations of standard
CLI tools and SDK clients. Each port lives in its own
`Sources/<TargetName>/` directory and gets a separate library +
executable product, but they share one `Package.swift`, one git
history, and one test runner.

## Today's targets

| Library  | Binary  | What it ports                                     |
|----------|---------|---------------------------------------------------|
| `ZipKit` | —       | Pure-Swift PKZIP archive operations on top of `weichsel/ZIPFoundation`. Shared by Zip / Unzip / GitHub. |
| `Zip`    | `zip`   | Info-ZIP `zip(1)` — create archives. |
| `Unzip`  | `unzip` | Info-ZIP `unzip(1)` — extract / list / test / pipe. |
| `GitHub` | `gh`    | GitHub CLI ([cli/cli](https://github.com/cli/cli)). |

**Planned next:** `GitLab` (parallel to `GitHub`).

## Build, test, run

```bash
swift build                              # builds everything
swift test                               # all targets, all tests (~133 today)
swift run gh ...                         # GitHub CLI
swift run zip ...                        # zip(1)
swift run unzip ...                      # unzip(1)
```

`swift build -c release` produces optimized binaries under
`.build/release/`.

## Layout

```
Sources/
  ZipKit/        — shared archive library (Archive, Entry, GlobMatcher, …)
  Zip/           — ZipCommand: AsyncParsableCommand
  ZipBin/        — @main wrapper, product alias → binary `zip`
  Unzip/         — UnzipCommand: AsyncParsableCommand
  UnzipBin/      — @main wrapper, product alias → binary `unzip`
  GitHub/        — gh's API client + Codable models + AsyncParsableCommand structs
  gh/            — @main wrapper for the gh binary
Tests/
  ZipKitTests/   — Archive round-trips, GlobMatcher
  ZipTests/      — ZipCommand argv parsing
  UnzipTests/    — UnzipCommand argv parsing
  GitHubTests/
    Fixtures/    — Captured GitHub API JSON responses
    *Tests/      — Decode tests, networking mocks, command parsing
```

## Naming conventions

- **Library target** = the upstream project / domain name, capitalized:
  `Zip`, `Unzip`, `ZipKit`, `GitHub`.
- **Executable target** name = same as the binary, lowercase: `zip`,
  `unzip`, `gh`. To dodge macOS's case-insensitive filesystem when an
  exec name collides with a library (`Zip` lib + `zip` exec), the
  exec target is suffixed `Bin` (`ZipBin`, `UnzipBin`) and the *binary
  name* is set via the product alias. The `gh` exec doesn't collide
  with the `GitHub` lib so no alias needed.
- **One declaration per file.** `Type+Concern.swift` extensions for
  splitting big types.
- File basenames must be **unique within a target**. SwiftPM's build
  output uses the basename for `.o` files; duplicates collide.

## Conventions inherited across all ports

- **Models are Codable structs**, one per file. Decoder is configured
  centrally via `JSONDecoder.gitHub()` style factories
  (snake_case → camelCase, ISO 8601 dates, base64 data).
- **Argument-Parser** for every CLI. `AsyncParsableCommand` for
  anything that does I/O; sync `ParsableCommand` for the very few
  pure-string subcommands.
- **Tests with Swift Testing** (`@Test`, `#expect`, `#require`) — not
  XCTest.
- **HTTP via `swift-http-types`** + `URLSession` from
  `HTTPTypesFoundation`. Mocked in tests with a `URLProtocol` subclass
  registered on an `URLSessionConfiguration`.
- **No `Process` shellouts** anywhere except in clearly-marked
  Mac/Linux-only paths. The `GitClient` protocol exists specifically
  so iOS / sandboxed embedders can inject `NoGitClient`.

## SwiftBash consumption

When [SwiftBash](../Experiments/SwiftBash) wants to register `zip` /
`unzip` (or any future CLI port) as a Bash builtin, it:

1. Adds a path or url dep on this package.
2. Adds a tiny extension file under `BashCommandKit/Commands/` that
   conforms the existing `*Command: AsyncParsableCommand` to
   `ParsableBashCommand`:

   ```swift
   import Unzip
   import BashInterpreter
   import ArgumentParser

   extension UnzipCommand: ParsableBashCommand {
       public mutating func execute() async throws -> ExitStatus {
           do { try await self.run(); return .success }
           catch let code as ExitCode { return ExitStatus(rawValue: Int(code.rawValue)) }
       }
   }
   ```

3. Registers via `shell.register(UnzipCommand.self)`.

The implementation lives here; the conformance lives in SwiftBash. No
cycle, no GitHub deps leaking into SwiftBash.

## GitHub / `gh` specifics

The `GitHub` target is the largest by far (~120 source files,
~89 commands). Detailed status, command inventory, and GitHub-specific
conventions: see [Docs/GitHub.md](Docs/GitHub.md).

Quick highlights:
- `auth login [--web] [--clipboard]` runs the OAuth device flow
  (covered by `Docs/OAuthAppSetup.md` for the publish-time client-ID
  swap).
- Token resolution: `GH_TOKEN > GITHUB_TOKEN > Keychain >
  ~/.config/gh/hosts.yml.oauth_token`.
- Repo inference from cwd via `git remote get-url origin`
  (`ProcessGitClient`).
- Adopts `swift-configuration`, `swift-http-types`, `swift-crypto`,
  `Yams`, Apple's `Security` framework.

## Adding a new port

1. Add a `Sources/<NewPort>/` directory + library target.
2. If it has a CLI binary, add a `Sources/<NewPort>Bin/` exec target
   with a 4-line `@main` wrapper, and an `.executable` product alias
   so the binary name doesn't collide with the library name.
3. Add tests under `Tests/<NewPort>Tests/`.
4. Update this AGENTS.md's table.
5. If SwiftBash should adopt it, the conformance + registration
   happens there.

## Skipped / out of scope

For the GitHub port specifically: `attestation` (Sigstore stack),
`codespace ssh` (dev-tunnels + PTY), `extension install` (Go-binary
plugin model), web-OAuth flow (browser + localhost listener; device
flow is sufficient).
