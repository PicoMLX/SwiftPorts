# SwiftPorts `Sandbox` module — pre-implementation audit

Audit for [issue #15](https://github.com/Cocoanetics/SwiftPorts/issues/15). This document is the deliverable required by Step 1 of that issue. **No production code has been written yet.** The audit's job is to confirm every URL/path/network/process touch in SwiftPorts and determine whether the proposed `Sandbox` design covers each cleanly. Where a site does not fit cleanly, it is flagged in [§ 5 — Open questions](#5--open-questions).

> **Rebase note.** This audit was rebased onto `main` after [#16 (cooperative cancellation)](https://github.com/Cocoanetics/SwiftPorts/pull/16) and [#14 (swift-archive upstream)](https://github.com/Cocoanetics/SwiftPorts/pull/14) merged. Two effects on the catalog:
> - **Line numbers may have drifted by ~1–10 in the compression and archive kits** because cancellation checkpoints (`try Task.checkCancellation()`) and async-throws conversions were inserted. **Symbol/function names remain authoritative**; navigate by symbol.
> - **All compression and archive public APIs are now already `async throws`**: `Gzip.compress`/`decompress`/`compressFile`/`decompressFile` and the same in Bzip2/Xz/Zstd/Lz4, plus `TarKit.Archive.extract`/`.create` and `ZipKit.Archive.extract`/`.create`. The proposed Phase 2 retrofit no longer requires sync→async signature changes for these — the `try await Sandbox.authorize(url)` insertions land cleanly in already-`async throws` bodies. Issue #15's note about "Sync APIs that need to gate become `async throws`" still applies to the remaining sync sites (`HostsFileStore.read/write`, `ConfigFileStore.read/write`, `Archive.streamEntries` if it stays sync, etc.) but the bulk of the cost is gone.
>
> Spot-checked the new `Sources/GitHub/Lib/IO/ZipExtractor.swift`: it delegates to already-cataloged `ZipKit.Archive` APIs and adds no new gated sites.

## 1 — Scope and conventions

A "**gated call site**" is any code that does I/O the proposed `Sandbox` would authorize:
- File I/O against a URL (read, write, create, remove, move, list, attribute, libarchive/libgit2 path-based C calls)
- Network I/O (`URLSession`, `HTTPTypesFoundation`, OAuth flows)
- Subprocess launches (`Process()` + `executableURL`)

An "**ambient-path construction**" is any code that reaches into process-global state to build a URL or path: `FileManager.default.currentDirectoryPath`, `NSTemporaryDirectory()`, `ProcessInfo.processInfo.environment["HOME"|"XDG_CONFIG_HOME"|...]`, `NSHomeDirectory()`, etc.

**Out of audit scope** — these don't go through the URL-based gate model:
- `FileHandle.standardInput` / `.standardOutput` / `.standardError` — process streams, not URL-addressed. Used pervasively by every `*Command` for CLI I/O. The gate model authorizes URLs; stdio isn't one. Treated as out of scope.
- Reads from `URLSession`'s response body to memory (the gate fires on the request URL, not on each chunk).
- Environment variable reads in general — flagged in § 5 as a follow-up scope question; not gated by `Sandbox.authorize(URL)`.

## 2 — Per-module catalog

### ForgeKit

#### List A — gated call sites

**Process launches (3 subsystems, all platform-gated):**
- [ProcessGitClient.swift](../ForgeKit/Git/ProcessGitClient.swift) — `ProcessGitClient.runGit(_:)` — `Process()` + `process.executableURL = URL(fileURLWithPath: gitPath)` + `process.run()` — launches `/usr/bin/env git ...` for read/write git ops. macOS/Linux/Windows only.
- [Browser.swift](../ForgeKit/IO/Browser.swift) — `Browser.runProcess(executable:args:)` — `Process()` + `executableURL` + `.run()` — launches `/usr/bin/open` (macOS) / `/usr/bin/env xdg-open|gio|gnome-open|kde-open` (Linux) / `cmd.exe /c start` (Windows) to open a URL in the user's browser.
- [Clipboard.swift](../ForgeKit/IO/Clipboard.swift) — `Clipboard.pipe(to:input:args:)` — `Process()` + `executableURL` + `.run()` + `inPipe.fileHandleForWriting.write(...)` — pipes a string into `/usr/bin/pbcopy` (macOS), `/usr/bin/env wl-copy|xclip` (Linux), or `clip.exe` (Windows).

**File I/O:** none. ForgeKit's `Lib/` is host-plumbing protocols; no direct file ops.

#### List B — ambient-path constructions

- [ProcessGitClient.swift:14](../ForgeKit/Git/ProcessGitClient.swift) — `ProcessGitClient.init` default — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath)` — defaults working directory to process CWD.
- [TTY.swift:55](../ForgeKit/IO/TTY.swift) — `TTY.isStdoutColorEnabled` — `ProcessInfo.processInfo.environment` — reads `NO_COLOR` / `CLICOLOR_FORCE`. Not URL-related; flagged in § 5 as "env-var ambient state".
- [Clipboard.swift:14](../ForgeKit/IO/Clipboard.swift) — `Clipboard.write` — `ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"]` — chooses `wl-copy` vs `xclip` based on display server.

---

### GzipKit

#### List A — gated call sites

- [Gzip.swift](../GzipKit/Lib/Gzip.swift) — `Gzip.compressFile(source:target:keepInput:)`:
  - `FileManager.default.fileExists(atPath: target.path)` — pre-flight existence check.
  - `Data(contentsOf: source)` — read input.
  - `compressed.write(to: target)` — write output.
  - `FileManager.default.removeItem(at: source)` — optional input cleanup.
- [Gzip.swift](../GzipKit/Lib/Gzip.swift) — `Gzip.decompressFile(source:target:keepInput:)`: same four operations, decompression direction.
- [GzipCommand.swift](../GzipKit/GzipCommand/GzipCommand.swift) — `GzipEngine.emitFileToStdout(url:)` — `Data(contentsOf: url)` for `zcat`-style stdout streaming.

#### List B — ambient-path constructions

- [GzipCommand.swift:188](../GzipKit/GzipCommand/GzipCommand.swift) — `GzipEngine.run` — `URL(fileURLWithPath: file)` on each CLI argument (relative, resolved against process CWD).
- [Gzip.swift:134](../GzipKit/Lib/Gzip.swift) — `Gzip.compressFile` default `target:` — derives output URL via `URL(fileURLWithPath: source.path + ".gz")`.
- [Gzip.swift:176-185](../GzipKit/Lib/Gzip.swift) — `Gzip.inferDecompressedName(for:)` — derives output URL by stripping `.gz`/`.tgz`/`.taz`/`.Z` from input path. Not ambient *per se* (input is caller-supplied), but uses `URL(fileURLWithPath:)` consistently with the relative-path convention.

---

### Bzip2Kit

#### List A — gated call sites

- [Bzip2.swift](../Bzip2Kit/Lib/Bzip2.swift) — `Bzip2.compressFile` / `.decompressFile` — same four-op pattern as GzipKit (existence check, read, write, optional remove).
- [Bzip2Command.swift](../Bzip2Kit/Bzip2Command/Bzip2Command.swift) — `Bzip2Engine.emitFileToStdout` — `Data(contentsOf:)`.

#### List B — ambient-path constructions

- Same shape as GzipKit: CLI argv → `URL(fileURLWithPath:)`, suffix-derived defaults (`.bz2`, `.tbz2` → `.tar`, `.tbz` → `.tar`).

---

### XzKit

#### List A — gated call sites

- [Xz.swift](../XzKit/Lib/Xz.swift) — `Xz.compressFile` / `.decompressFile` — same four-op pattern.
- [XzCommand.swift](../XzKit/XzCommand/XzCommand.swift) — `XzEngine.emitFileToStdout` — `Data(contentsOf:)`.

#### List B — ambient-path constructions

- Same shape as GzipKit: CLI argv → `URL(fileURLWithPath:)`, suffix-derived defaults (`.xz`, `.lzma`, `.txz` → `.tar`).

---

### ZstdKit

#### List A — gated call sites

- [Zstd.swift](../ZstdKit/Lib/Zstd.swift) — `Zstd.compressFile` / `.decompressFile` — same four-op pattern.
- [ZstdCommand.swift](../ZstdKit/ZstdCommand/ZstdCommand.swift) — `ZstdEngine.emitFileToStdout` — `Data(contentsOf:)`.

#### List B — ambient-path constructions

- Same shape as GzipKit: CLI argv → `URL(fileURLWithPath:)`, suffix-derived defaults (`.zst`, `.tzst` → `.tar`).

---

### Lz4Kit

#### List A — gated call sites

- [Lz4.swift](../Lz4Kit/Lib/Lz4.swift) — `Lz4.compressFile` / `.decompressFile` — same four-op pattern.
- [Lz4Command.swift](../Lz4Kit/Lz4Command/Lz4Command.swift) — `Lz4Engine.emitFileToStdout` — `Data(contentsOf:)`.

#### List B — ambient-path constructions

- Same shape as GzipKit: CLI argv → `URL(fileURLWithPath:)`, suffix-derived defaults (`.lz4`, `.tlz4` → `.tar`).

---

### TarKit

#### List A — gated call sites

- [Archive.swift](../TarKit/Lib/Archive.swift) — `Archive.extract(at:to:options:)`:
  - `FileManager.default.createDirectory` — create extraction root.
  - Per-entry, inside the libarchive walk loop:
    - `FileManager.default.fileExists` — collision check.
    - `FileManager.default.createDirectory` — create entry directory or parent dirs for files / symlinks.
    - `FileManager.default.removeItem` — remove existing entry on collision.
    - `FileManager.default.createSymbolicLink` — symlink entry.
    - `Data.write(to:)` — file entry bytes.
- [Archive.swift](../TarKit/Lib/Archive.swift) — `Archive.create(at:files:options:)`:
  - `FileManager.default.fileExists` — output exists check.
  - `FileManager.default.removeItem` — remove existing output.
  - `FileManager.default.createDirectory` — create parent dirs for output.
  - `ArchiveWriter.init(...)` — libarchive opens output by path (C call).
- [Archive.swift](../TarKit/Lib/Archive.swift) — `Archive.walk` (creation traversal, recursive):
  - `FileManager.default.attributesOfItem` — read mode/symlink status.
  - `FileManager.default.contentsOfDirectory` — list directory entries.
  - `FileManager.default.destinationOfSymbolicLink` — read symlink target.
  - `Data(contentsOf:)` — read file contents into archive.

#### List B — ambient-path constructions

- [TarCommand.swift:111-151](../TarKit/TarCommand/TarCommand.swift) — `TarCommand.runCreate` / `.runExtract` / `.runList` — every CLI arg path goes through `URL(fileURLWithPath:)` (relative, resolved against CWD).
- [TarCommand.swift:133](../TarKit/TarCommand/TarCommand.swift) — `TarCommand.runExtract` default destination — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)`.

---

### ZipKit

#### List A — gated call sites

- [Archive.swift](../ZipKit/Lib/Archive.swift) — `Archive.extract(at:to:options:)`:
  - `FileManager.default.createDirectory` — extraction root.
  - Per-entry: same shape as TarKit's extract (`fileExists`, `removeItem`, `createDirectory`, `createSymbolicLink`, `Data.write`).
- [Archive.swift](../ZipKit/Lib/Archive.swift) — `Archive.streamEntries(...)` — `FileHandle.write(...)` for streaming extraction to a caller-supplied file handle. **Note**: caller-supplied `FileHandle` blurs the gate boundary; flagged in § 5.
- [Archive.swift](../ZipKit/Lib/Archive.swift) — `Archive.create(at:files:options:)`:
  - `FileManager.default.fileExists` — output exists.
  - `FileManager.default.removeItem` — clobber existing.
  - `ArchiveWriter.init(...)` — libarchive opens output by path.
  - Walk traversal: `FileManager.default.attributesOfItem`, `.destinationOfSymbolicLink`, `.contentsOfDirectory`, `Data(contentsOf:)`.
- [UnzipCommand.swift](../ZipKit/UnzipCommand/UnzipCommand.swift) — `UnzipCommand.run` — `FileHandle.standardInput.readDataToEndOfFile()` when archive is `-`. (Stdio, out of scope.)

#### List B — ambient-path constructions

- [UnzipCommand.swift](../ZipKit/UnzipCommand/UnzipCommand.swift) — `UnzipCommand.run` / `.doExtract` — `URL(fileURLWithPath:)` on argv archive path and destination dir (default `"."`).
- [ZipCommand.swift](../ZipKit/ZipCommand/ZipCommand.swift) — `ZipCommand.run` — `URL(fileURLWithPath:)` on argv input/output paths.

---

### JqKit

#### List A — gated call sites

- [JqCommand.swift](../JqKit/JqCommand/JqCommand.swift) — `JqExecutable.run`:
  - `Data(contentsOf: url)` for `--slurpfile` / `--rawfile` arguments.
  - `Data(contentsOf: url)` for each positional input file.
  - `FileHandle.standardInput.readDataToEndOfFile()` for stdin (out of scope).

#### List B — ambient-path constructions

- [JqCommand.swift:140, 229](../JqKit/JqCommand/JqCommand.swift) — `URL(fileURLWithPath:)` on file-path arguments.
- [JqCommand.swift:276](../JqKit/JqCommand/JqCommand.swift) — `JqExecutable.run` — `ProcessInfo.processInfo.environment` — exposes the entire process environment dict to the jq filter via `env`/`$ENV` builtins. **Flagged in § 5** — env exfiltration is a sandbox concern, but env access isn't URL-gated.

---

### GitHub

#### List A — gated call sites

**Lib/ — Configuration:**
- [HostsFile.swift](../GitHub/Lib/Configuration/HostsFile.swift) — `HostsFileStore.read()`:
  - `FileManager.default.fileExists(atPath: path.path)` — exists check.
  - `String(contentsOf: path, encoding: .utf8)` — read YAML.
- [HostsFile.swift](../GitHub/Lib/Configuration/HostsFile.swift) — `HostsFileStore.write(_:)`:
  - `yaml.write(to: path, atomically:, encoding:)` — write YAML.
  - `FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)` — chmod 0600.
- [HostsFile.swift](../GitHub/Lib/Configuration/HostsFile.swift) — `HostsFileStore.ensureDirectoryExists()` — `FileManager.default.createDirectory(at:, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])`.
- [ConfigFile.swift](../GitHub/Lib/Configuration/ConfigFile.swift) — `ConfigFileStore.read()` / `.write(_:)` / `.ensureDirectoryExists()` — same shape as HostsFile.

**Lib/ — Networking (centralized):**
- [APIClient.swift](../GitHub/Lib/Networking/APIClient.swift) — `APIClient.perform(_:)` — `session.data(for:)` and `session.upload(for:from:)` for all REST calls (typed `get<T>()`, `paginate<T>()`, `send<Body, Response>()`, `delete()`, `raw()`). One gate covers them all.
- [GraphQLClient.swift](../GitHub/Lib/GraphQL/GraphQLClient.swift) — `GraphQLClient.rawQuery(_:variables:)` — `session.upload(for:from:)` for `/graphql`.
- [OAuthDeviceFlow.swift](../GitHub/Lib/Auth/OAuthDeviceFlow.swift) — `OAuthDeviceFlow.requestDeviceCode()` and `.exchangeOnce()` — `session.upload(for:from:)` against `https://github.com/login/device/code` and `/login/oauth/access_token`.

**GhCommand/ — Subcommand-level FS:**
- [ReleaseDownload.swift](../GitHub/GhCommand/Subcommands/Release/ReleaseDownload.swift) — `ReleaseDownload.run`:
  - `FileManager.default.createDirectory` — destination dir.
  - `URLSession(configuration: .default)` (constructed) + `session.data(from: asset.browserDownloadUrl)` — direct asset download.
  - `data.write(to: dest)` — write asset.
  - `FileManager.default.removeItem(at:)` — optional archive cleanup with `--no-keep-archive`.
- [ReleaseDownload.swift:199, 212](../GitHub/GhCommand/Subcommands/Release/ReleaseDownload.swift) — `ArchiveFormatDetector.extract` — `FileManager.default.removeItem(at:)` cleanup of staged `.tar.lz4` / `.tar.xz` intermediates.
- [RunDownload.swift](../GitHub/GhCommand/Subcommands/Run/RunDownload.swift) — `RunDownload.run`:
  - `FileManager.default.createDirectory` — destination dir.
  - `client.raw(...)` (302 → S3) + `response.body.write(to:)` — write artifact zip.
- [GistCreate.swift](../GitHub/GhCommand/Subcommands/Gist/GistCreate.swift) — `GistCreate.run` — `Data(contentsOf:)` for each gist file.

**GhCommand/ — Subcommand-level network (all flow through `APIClient` and are gated by the single `APIClient.perform` gate above):**
- ~60+ subcommands across Pr/Issue/Release/Cache/Variable/Label/Search/Org/Auth/Browse/Repo using `client.get/.send/.delete/.raw` and `gqlClient.query`. Enumerated by the audit; not repeated here because **all of them are subsumed by the single `APIClient.perform` and `GraphQLClient.rawQuery` gates**. Adding a gate at those two functions covers the entire GitHub command tree.

#### List B — ambient-path constructions

- [HostsFile.swift:67-83](../GitHub/Lib/Configuration/HostsFile.swift) — `HostsFileStore.defaultPath`:
  - `ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]`
  - fallback: `ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()`
  - composes `<configdir>/gh/hosts.yml`.
- [ConfigFile.swift:34-52](../GitHub/Lib/Configuration/ConfigFile.swift) — `ConfigFileStore.defaultPath` — same XDG/HOME/NSHomeDirectory composition for `<configdir>/gh/config.yml`.
- [ConfigurationResolver.swift:83](../GitHub/Lib/Configuration/ConfigurationResolver.swift) — `ConfigurationResolver` — `ProcessInfo.processInfo.environment` (full dict, parameter-defaulted) for token discovery (`GITHUB_TOKEN`, `GH_TOKEN`).
- [CommandContext.swift:35](../GitHub/GhCommand/CommandContext.swift) — `CommandContext.gitClient` — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath)`.
- [ReleaseDownload.swift:70](../GitHub/GhCommand/Subcommands/Release/ReleaseDownload.swift) — `ReleaseDownload.run` — `URL(fileURLWithPath: dir, isDirectory: true)` from `--dir` arg (relative).
- [ReleaseDownload.swift:226](../GitHub/GhCommand/Subcommands/Release/ReleaseDownload.swift) — `ArchiveFormatDetector.makeStagingTarURL` — `URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)`. **Only `NSTemporaryDirectory()` use in the codebase.**
- [RunDownload.swift:61](../GitHub/GhCommand/Subcommands/Run/RunDownload.swift) — `RunDownload.run` — `URL(fileURLWithPath: dir, isDirectory: true)`.
- [GistCreate.swift:46](../GitHub/GhCommand/Subcommands/Gist/GistCreate.swift) — `GistCreate.run` — `URL(fileURLWithPath: filePath)` on each gist input file (relative).
- [RepoFork.swift:55](../GitHub/GhCommand/Subcommands/Repo/RepoFork.swift) — `RepoFork.run` — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath)`.
- [RepoClone.swift:50](../GitHub/GhCommand/Subcommands/Repo/RepoClone.swift) — `RepoClone.run` — `URL(fileURLWithPath: dir)` from optional clone-destination arg.

---

### GitLab

#### List A — gated call sites

**Lib/ — Networking:**
- [APIClient.swift](../GitLab/Lib/Networking/APIClient.swift) — `APIClient.perform(_:)` — `session.data(for:)` and `session.upload(for:from:)`. Same single-gate centralization as GitHub.

**GlabCommand/ — Subcommand-level FS:**
- [CiLint.swift](../GitLab/GlabCommand/Subcommands/CI/CiLint.swift) — `CiLint.run` — `String(contentsOf: url, encoding: .utf8)` reads `.gitlab-ci.yml` (or `--path`).
- [ReleaseCreate.swift](../GitLab/GlabCommand/Subcommands/Release/ReleaseCreate.swift) — `ReleaseCreate.run` — `String(contentsOf: url, encoding: .utf8)` reads release notes file.
- [ReleaseDownload.swift](../GitLab/GlabCommand/Subcommands/Release/ReleaseDownload.swift) — same shape as GitHub: `FileManager.default.createDirectory`, `URLSession.data(from:)`, `data.write(to:)`.

**GlabCommand/ — Subcommand-level network:** ~40+ subcommands flowing through `client.get/.send/.delete/.raw`. Same observation as GitHub: all subsumed by the single `APIClient.perform` gate.

#### List B — ambient-path constructions

- [Configuration.swift:27](../GitLab/Lib/Configuration/Configuration.swift) — `Configuration.live()` — `ProcessInfo.processInfo.environment` (full dict) for `GITLAB_HOST` / `GITLAB_URI` / `GL_HOST` / `GITLAB_TOKEN` / `GITLAB_ACCESS_TOKEN` / `OAUTH_TOKEN`.
- [ConfigurationResolver.swift:64](../GitLab/Lib/Configuration/ConfigurationResolver.swift) — `TokenSource.detect()` — `ProcessInfo.processInfo.environment` (full dict, parameter-defaulted).
- [CommandContext.swift:26](../GitLab/GlabCommand/CommandContext.swift) — `CommandContext.gitClient` default `workingDirectory:` — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath)`.
- [CiLint.swift:37](../GitLab/GlabCommand/Subcommands/CI/CiLint.swift) — `URL(fileURLWithPath:)` on `--path` arg.
- [ReleaseDownload.swift:70](../GitLab/GlabCommand/Subcommands/Release/ReleaseDownload.swift) — `URL(fileURLWithPath: dir, isDirectory: true)` from `--dir`.
- [ReleaseCreate.swift:51](../GitLab/GlabCommand/Subcommands/Release/ReleaseCreate.swift) — `URL(fileURLWithPath:)` on `--notes-file`.
- [RepoClone.swift:35](../GitLab/GlabCommand/Subcommands/Repo/RepoClone.swift) — `URL(fileURLWithPath:)` on optional destination dir arg.

GitLab does **not** have on-disk config files (no `~/.config/glab/...` reads in current code) — it sources config from env vars exclusively. Differs from GitHub.

---

### SwiftGit

#### List A — gated call sites

**libgit2 path-based C calls (the path is what `Sandbox` would authorize before the C call):**
- [GitClient.swift:119](../SwiftGit/Lib/GitClient.swift) — `GitClient.clone(url:into:)` — `git_clone(&repo, url.absoluteString, dest, &opts)` — opens destination at `<dest>`. Gates: clone-source URL (network) + destination URL (file).
- [GitClient.swift:431](../SwiftGit/Lib/GitClient.swift) — `GitClient.withRepository(_:body:)` — `git_repository_open_ext(&repo, workingDirectory.path, 0, nil)` — opens existing repo at `<workingDirectory>`. Used by every read-only inspection method (`localBranches`, `remoteExists`, `isIgnored`, log, diff, etc.).
- [GitClient+Init.swift:43-46](../SwiftGit/Lib/GitClient+Init.swift) — `GitClient.initRepository` — `git_repository_init_ext(&repo, workingDirectory.path, &opts)` — initializes repo at `<workingDirectory>`.

**FileManager:**
- [GitClient+Init.swift:24](../SwiftGit/Lib/GitClient+Init.swift) — `GitClient.initRepository` — `FileManager.default.createDirectory(at:withIntermediateDirectories:true)` — pre-creates working dir.
- [GitClient+MvRm.swift:45-51](../SwiftGit/Lib/GitClient+MvRm.swift) — `GitClient.move` — `FileManager.default.fileExists` + `.moveItem(at:to:)`.
- [ProgressReporter.swift:83](../SwiftGit/Lib/ProgressReporter.swift) — `ProgressReporter.isLocalURL` — `FileManager.default.fileExists(atPath:)` — checks whether a remote URL string is actually a local path (for `clone` UX).
- [GitCommand subcommands](../SwiftGit/GitCommand/Subcommands/) — `Apply.run`, `Blame.run`: `Data(contentsOf:)` / `String(contentsOf:)` for caller-supplied patch/blame target files. `Add.run`, `Diff.looksLikePath`, `Clean.run`: `FileManager.default.fileExists` for path resolution; `Clean.run`: `FileManager.default.removeItem(at:)` for untracked-file cleanup.

**Network:** None directly. libgit2's `fetch`/`push` use libgit2's own transport layer (libssh2, native HTTP). Not visible at the Swift level. Authorization would have to gate libgit2 transport callbacks, which is a richer design than the URL-only `Sandbox` proposes. **Flagged in § 5.**

**Process launches:** None. SwiftGit is libgit2-in-process throughout.

#### List B — ambient-path constructions

- [GitClient.swift:25](../SwiftGit/Lib/GitClient.swift) — `GitClient.init` default `workingDirectory:` — `URL(fileURLWithPath: FileManager.default.currentDirectoryPath)`.
- [SignatureResolver.swift:32](../SwiftGit/Lib/SignatureResolver.swift) — `SignatureResolver.resolve` — `ProcessInfo.processInfo.environment` (full dict) for `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_*` / `EMAIL`.
- [GitCommand/CommandContext.swift:11, 26](../SwiftGit/GitCommand/CommandContext.swift) — `CommandContext.currentDirectory` and `.envCredentialProvider` — CWD + `ProcessInfo.processInfo.environment` (full dict) for `GH_TOKEN`/`GITHUB_TOKEN`/`GITLAB_TOKEN`/`GIT_USERNAME`/`GIT_PASSWORD`.
- [GitCommand/Subcommands/Archive.swift:44](../SwiftGit/GitCommand/Subcommands/Archive.swift), [Diff.swift:217](../SwiftGit/GitCommand/Subcommands/Diff.swift), [RevParse.swift:93](../SwiftGit/GitCommand/Subcommands/RevParse.swift) — `FileManager.default.currentDirectoryPath` for path resolution / git-dir formatting.

---

## 3 — Aggregate counts

| Module | List A (gated) | List B (ambient) |
|---|---|---|
| ForgeKit | 3 process subsystems | 1 CWD, 2 env-var |
| GzipKit | 8 file ops, 1 stdio (out of scope) | 1 CWD-relative argv, 1 derived suffix |
| Bzip2Kit | 8 + 1 stdio | same shape |
| XzKit | 8 + 1 stdio | same shape |
| ZstdKit | 8 + 1 stdio | same shape |
| Lz4Kit | 8 + 1 stdio | same shape |
| TarKit | ~14 file ops in extract+create+walk; 1 libarchive path-open | 4 CWD-relative argv |
| ZipKit | ~16 file ops; 1 libarchive path-open; 1 streamEntries FH | 3 CWD-relative argv |
| JqKit | 2 file ops, 1 stdio | 2 CWD-relative argv, 1 full env |
| GitHub | 10 file ops (config), 5 lib-level network gates that subsume ~60+ subcommand calls, 4 download/upload sites in subcommands | 2 XDG_CONFIG_HOME+HOME composers, 1 NSTemporaryDirectory, 1 full env, 4 CWD-relative argv |
| GitLab | 1 lib-level network gate that subsumes ~50+ subcommand calls, 4 file ops in subcommands | 2 full env reads, 4 CWD-relative argv |
| SwiftGit | 7 file/libgit2 path ops, ~10 FileManager touches in subcommands | 4 CWD reads, 2 full env reads |

**Wide-sweep verification** confirmed by the fourth agent: zero stray `FileManager.default`, `URLSession`, `Process`, or ambient-path patterns appear in `Sources/` outside the 12 audited modules. The C systemLibrary shims (`CZlib`, `CBzip2`, `CLZMA`, `CZstd`, `CLz4`) contain no Swift logic. `Tests/` uses ambient APIs in setup/teardown but none are reused by `Sources/`.

## 4 — Region-set confirmation

**The proposed `Sandbox` struct mirrors Foundation's full `URL` static directory surface:** `documentsDirectory`, `downloadsDirectory`, `libraryDirectory`, `moviesDirectory`, `musicDirectory`, `picturesDirectory`, `sharedPublicDirectory`, `temporaryDirectory`, `trashDirectory`, `userDirectory`, plus SwiftPorts additions `homeDirectory` and `cachesDirectory`.

**What SwiftPorts actually consumes today:**

| Region | Consumed by SwiftPorts? | Where |
|---|---|---|
| `currentDirectory` (CWD) | **Yes** — heavily | 10 sites across ForgeKit, TarKit, GitHub, GitLab, SwiftGit |
| `temporaryDirectory` | Yes (1 site) | `ReleaseDownload` staging tar via `NSTemporaryDirectory()` |
| `homeDirectory` | Yes (2 sites, indirect) | GitHub `HostsFile` / `ConfigFile` via `$HOME` / `NSHomeDirectory()` |
| `documentsDirectory` | No | — |
| `cachesDirectory` | No | — |
| `downloadsDirectory` | No | — |
| `libraryDirectory` | No | — |
| `moviesDirectory` | No | — |
| `musicDirectory` | No | — |
| `picturesDirectory` | No | — |
| `sharedPublicDirectory` | No | — |
| `trashDirectory` | No | — |
| `userDirectory` | No | — |

Two findings:

**(a) `currentDirectory` is missing from the proposed `Sandbox` surface.** It's not a Foundation `URL.<X>Directory` accessor (CWD is process-global state via `FileManager.currentDirectoryPath`), but it's the single most-consumed ambient API in SwiftPorts. The proposed struct must add it:

```swift
public let currentDirectory: URL    // sandboxed CLI default; not from Foundation static URL set
public static var currentDirectory: URL {
    current?.currentDirectory
        ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}
```

For `rooted(at: root)`, `currentDirectory` defaults to `root` itself. For `appContainer(id:)`, defaults to `documentsDirectory`. CLI commands that today use `FileManager.default.currentDirectoryPath` to resolve relative argv paths switch to `Sandbox.currentDirectory`.

**(b) The Foundation surface beyond `temporaryDirectory` / `homeDirectory` is for *embedder* policy, not SwiftPorts internal use.** `documentsDirectory`, `cachesDirectory`, etc. exist in the struct so an embedder (SwiftBash, an iOS app) can describe its policy completely. No SwiftPorts call site reaches for them today, and the audit doesn't surface a need to add any. Keep them for embedder API completeness; don't remove.

## 5 — Open questions

These are the sites that don't fit the "URL in → authorize-then-do → throw on deny" model cleanly. Per the issue spec, the agent should not proceed to Step 2 until each is answered. Issue #15 already commits to specific answers for some of these; restating here for explicitness, raising the genuinely-new ones for direction.

### 5.1 — CLI relative-path resolution

**The pattern.** Most `*Command` subcommands accept user paths as `String` and convert via `URL(fileURLWithPath:)`. That constructor resolves relative paths against process CWD (`FileManager.default.currentDirectoryPath`) — which is a process-global, not a `Sandbox` value.

**Examples.** `TarCommand.runCreate`, `GzipEngine.run`, `JqExecutable.run`, `RepoClone.run`, `GistCreate.run`, `CiLint.run`, every compression command's argv handling.

**The conflict.** Issue #15 says "Reject relative URLs at public APIs" — but these are CLI surfaces accepting user input. Library APIs already receive absolute URLs from caller-supplied destinations; the relative-path wart is at the CLI layer.

**Proposed answer.** CLI commands resolve via `Sandbox.currentDirectory` instead of `FileManager.default.currentDirectoryPath`. Library APIs (e.g. `Gzip.compressFile(source:target:)`, `TarKit.Archive.extract(at:to:)`) precondition on absolute URLs; CLI layer is responsible for resolving before calling them. This stays consistent with the issue's design — relative paths still don't reach the library — but acknowledges the CLI is the natural resolver.

This requires the new `Sandbox.currentDirectory` from § 4(a).

### 5.2 — Ambient env-var reads

**The pattern.** Six call sites read `ProcessInfo.processInfo.environment` (some single keys, some full dict): TTY color detection, Wayland detection, GitHub/GitLab token discovery, libgit2 signature resolution, jq's `env`/`$ENV` exposure, and most importantly `HostsFile.defaultPath` / `ConfigFile.defaultPath` constructing config paths via `$XDG_CONFIG_HOME` / `$HOME`.

**The conflict.** Env reads are not URL-addressed I/O. They're not gated by `Sandbox.authorize(URL)`. But they ARE process-ambient state that an embedder may want to control — e.g. SwiftBash-as-host wants to substitute its own scripted env, not leak the parent process's `$HOME` or `$GITLAB_TOKEN` into a sandboxed task.

**Proposed answer.** Out of v1 scope. The issue is URL-gating; env-virtualization is a separate concern. Document explicitly in `Sandbox` that env-var ambient reads are not gated. File a follow-up issue: *"Add `Sandbox.environment` for ambient env-var virtualization"*.

**Two specific subcases that DO need handling in v1:**
- **`HostsFile` / `ConfigFile` config-path construction** (§ 5.3) — these aren't really env-var concerns; they're configuration paths that should be parameterized.
- **JqKit's whole-env exposure to filters** — `env`/`$ENV` builtins read the full `ProcessInfo` dict. Under sandbox this leaks the host process's env into untrusted jq filters. **Proposal**: when `Sandbox.current != nil`, JqKit feeds an empty env dict to the filter. Treat this as a Phase 2 retrofit task, with a one-line conditional. **Confirm.**

### 5.3 — `HostsFile` / `ConfigFile` config-path construction (configuration-object refactor)

**The pattern.** [`HostsFile.swift:67-83`](../GitHub/Lib/Configuration/HostsFile.swift) and [`ConfigFile.swift:34-52`](../GitHub/Lib/Configuration/ConfigFile.swift) compute their default path from `$XDG_CONFIG_HOME`, falling back to `$HOME`, falling back to `NSHomeDirectory()`. The path is `static var defaultPath`, used as the `init(path:)` default.

**Why this needs explicit refactor.** The issue's guiding principle is "no resolver inside SwiftPorts; ambient paths come from `Sandbox.<region>`". `HostsFile.defaultPath` is currently the only call site that conditionally chains XDG → HOME → NSHomeDirectory. Under sandbox, `$HOME` and `$XDG_CONFIG_HOME` may be unset or point outside the sandbox.

**Proposed answer.** Phase 2 refactor:

```swift
extension HostsFileStore {
    public static var defaultPath: URL {
        Sandbox.homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("gh", isDirectory: true)
            .appendingPathComponent("hosts.yml")
    }
}
```

`Sandbox.homeDirectory` returns the sandbox's home (under-root `<root>/home` for `rooted(at:)`; `Documents` for `appContainer`) when set, and `FileManager.default.homeDirectoryForCurrentUser` when not — preserving today's behavior on macOS but introducing iOS-availability. The XDG_CONFIG_HOME special case is dropped in the sandboxed code path; XDG semantics belong to the embedder, who can set `homeDirectory` to wherever they want config to live.

**Caveat.** Today's code explicitly avoids `homeDirectoryForCurrentUser` because it's iOS-unavailable. The fallback in `Sandbox.homeDirectory` (the static accessor) needs to handle iOS — `FileManager.default.homeDirectoryForCurrentUser` is iOS-unavailable, so the fallback should be `NSHomeDirectory()` or `URL.documentsDirectory` on iOS. Worth pinning down before the refactor.

Same refactor applies to `ConfigFile.defaultPath`. **Confirm direction.**

### 5.4 — `ZipKit.Archive.streamEntries` accepts caller-supplied `FileHandle`

[`Archive.swift`](../ZipKit/Lib/Archive.swift) — `Archive.streamEntries(...)` writes extracted entries to a caller-supplied `FileHandle` rather than to a URL the function controls. The handle was opened by the caller — at that point the URL is already consumed, and the gate fired (or didn't) on the caller's side. This is fine **if** every caller of `streamEntries` is itself gated.

**Proposed answer.** Out of scope for the gate itself. The gate is at URL-open time, not at write-to-FH time. Document that callers of `streamEntries` are responsible for gating the `FileHandle`'s underlying URL before calling. No code change needed; just a doc note. **Confirm.**

### 5.5 — `ProgressReporter.isLocalURL` probes

[`ProgressReporter.swift:83`](../SwiftGit/Lib/ProgressReporter.swift) calls `FileManager.default.fileExists(atPath: url)` to detect whether a `clone` source string is a local path (so it can show "Cloning from local..." UX). This is a *probe*, not an actual file open — but it leaks information about the host filesystem to anyone watching for divergent behavior.

**Proposed answer.** Gate the probe URL like any other file access. The gatekeeper denies → the function returns `false` (treats as non-local) without leaking. Trivial change, mentioned for completeness. **Confirm.**

### 5.6 — libgit2's internal network/file ops

**The pattern.** SwiftGit's `clone` / `fetch` / `push` invoke libgit2, which then opens its own TCP connections (libssh2/native HTTP) and writes its own files inside the repo. These are not visible at the Swift call boundary — by the time we've handed `git_clone` a URL and a destination, libgit2 will do everything else in C.

**The conflict.** A URL-level gate at the Swift call site authorizes the *initial* URL. libgit2's internal HTTP/SSH connections to the remote, its temp-file scratchwork inside `.git/`, and its packfile network reads happen below the Swift gate.

**Proposed answer.** **Two-tier gate:**
- **Tier 1, Swift call site:** authorize the user-supplied URL (clone source, fetch URL) and the destination path. This is what `Sandbox.authorize` does today.
- **Tier 2, libgit2 callbacks (deferred):** libgit2 supports `git_remote_callbacks.transport` / `credentials` / `certificate_check` callbacks. We could route those into `Sandbox.authorize`. Deferred to a follow-up issue — significant work, not v1.

For v1: gate the URLs we hand libgit2 at the Swift boundary. Document that libgit2's internal network/FS ops are not gated. Embedders that need stricter network confinement than this layer provides should not use SwiftGit's network ops in untrusted contexts (or wait for tier-2). **Confirm.**

### 5.7 — `FileHandle.standardInput/Output/Error` reads/writes

Pervasive across every `*Command`. Stdio is a process stream, not URL-addressed I/O.

**Proposed answer.** Explicitly out of scope. Document in `Sandbox`'s docs. Embedders that want to virtualize stdio do so at the `*Command`'s `AsyncParsableCommand` invocation boundary (replacing handles before `run()`), not via `Sandbox`. **Confirm.**

### 5.8 — Process-launch executable URLs

ForgeKit's three subsystems (Git via Process, Browser, Clipboard) construct executable URLs from string literals (`/usr/bin/open`, `/usr/bin/env`, `cmd.exe`) and pass them to `process.executableURL`.

**Proposed answer.** Already covered by the issue's design. Each `Process.run()` call site is preceded by `try await Sandbox.authorize(executableURL)`. Under `rooted(at:)`, those URLs aren't under root → denied. Embedders wanting `git` access route through `SwiftGit.GitClient` (libgit2, no Process). Embedders wanting browser/clipboard access in sandbox don't get them — those subsystems simply don't function. No code change needed beyond inserting the gate.

---

## 6 — Resolved direction (after design discussion on issue #15)

The eight open questions from § 5 were discussed and resolved. Recorded here so an agent picking this branch up has the v1 contract written down.

### 6.1 — Unifying primitive: `Sandbox` shadows `ProcessInfo` reads

`Sandbox` shadows the two `ProcessInfo.processInfo` reads that SwiftPorts code consumes — `environment` and `arguments` — by **code convention**, not a runtime hook. Every SwiftPorts source site that today reads `ProcessInfo.processInfo.environment` or `CommandLine.arguments` migrates to `Sandbox.environment` / `Sandbox.arguments` (or per-key sugar `Sandbox.env(_:)`).

**Honest scope.** This is *not* a process-wide override of `ProcessInfo`. Foundation internals, libgit2's own `getenv()` calls, and any third-party Swift dependency still see the real process env. The shadow only applies to code we control and migrate. v1 makes no promise about env isolation inside libgit2 or Foundation.

**Default-deny.** When `Sandbox.current != nil`, the embedder is fully in charge — the default `environment: { [:] }` and `arguments: { [] }` closures return empty. SwiftPorts sees no env / no argv. Embedders who want host passthrough write it explicitly: `environment: { ProcessInfo.processInfo.environment }`. Same posture as the URL gate (default-deny when configured, default-permit when `Sandbox.current == nil`).

**Closure shape.** Both are `@Sendable () -> ...` closures, not stored snapshots. This bridges cleanly to a class-backed mutable env in a future Shell type without `@TaskLocal` re-binding on every mutation.

### 6.2 — Per-question resolutions

| § | Question | v1 resolution |
|---|---|---|
| 5.1 | CLI relative-path resolution | `Sandbox.currentDirectory` (computed, derived from `PWD` env key — falls back to process CWD when `current == nil`). CLI commands resolve relative argv via `Sandbox.currentDirectory`. Library APIs precondition on absolute URLs. **No separate stored field — single source of truth is `environment`'s `PWD`.** |
| 5.2-general | Six env-reads in `Sources/` | Migrate to `Sandbox.env(_:)` / `Sandbox.environment`. v1 scope. |
| 5.2-jq | JqKit `env` / `$ENV` filter exposure | Read via `Sandbox.environment`. v1 scope. |
| 5.3 | `HostsFile` / `ConfigFile` config-path | Read via `Sandbox.env("XDG_CONFIG_HOME")` falling back to `Sandbox.homeDirectory.appendingPathComponent(".config", ...)`. iOS-availability handled in `Sandbox.homeDirectory`'s static fallback (`#if os(iOS)…` → `NSHomeDirectory()`). |
| 5.4 | `ZipKit.streamEntries` caller-supplied `FileHandle` | Doc note. Caller is responsible for authorizing the URL backing the handle. No code change. |
| 5.5 | `ProgressReporter.isLocalURL` probe | Doc note. The probe is metadata-only (UX classification); the actual file open by libgit2 falls under § 5.6 anyway. No code change. |
| 5.6 | libgit2 internal network/FS ops | Tier-1 only in v1: gate URLs at the Swift call boundary (`git_clone` source URL + dest path, `git_repository_open_ext` path, `git_repository_init_ext` path). Tier-2 (libgit2 transport / credentials / certificate callbacks) deferred to follow-up issue. |
| 5.7 | `FileHandle.standardInput/Output/Error` | Out of scope. Doc note. Embedders virtualize stdio at the `AsyncParsableCommand` invocation boundary. |
| 5.8 | Process executable URLs | Already covered: insert `try await Sandbox.authorize(executableURL)` at the three `Process.run()` sites in ForgeKit. Under `rooted(at:)`, denied; embedders use `SwiftGit.GitClient` (libgit2) for git, accept that browser/clipboard don't function. |

### 6.3 — Final `Sandbox` API shape (locked for Phase 1 implementation)

```swift
public struct Sandbox: Sendable {
    @TaskLocal public static var current: Sandbox?

    // Foundation URL.<X>Directory mirror (stored)
    public let documentsDirectory: URL
    public let downloadsDirectory: URL
    public let libraryDirectory: URL
    public let moviesDirectory: URL
    public let musicDirectory: URL
    public let picturesDirectory: URL
    public let sharedPublicDirectory: URL
    public let temporaryDirectory: URL
    public let trashDirectory: URL
    public let userDirectory: URL
    public let homeDirectory: URL
    public let cachesDirectory: URL

    // ProcessInfo shadow (closures)
    public let environment: @Sendable () -> [String: String]
    public let arguments: @Sendable () -> [String]

    // URL gate
    private let _authorize: @Sendable (URL) async throws -> Void
    public func authorize(_ url: URL) async throws { try await _authorize(url) }

    // currentDirectory derived from PWD env key, NOT a stored field
    // (single source of truth: environment closure)

    // Static accessors with platform-aware fallbacks when current == nil

    public static func authorize(_ url: URL) async throws
    public static var environment: [String: String]
    public static func env(_ key: String) -> String?
    public static var arguments: [String]
    public static var currentDirectory: URL
    // ... per-region accessors (homeDirectory/cachesDirectory/temporaryDirectory/...)

    // Built-in factories
    public static func rooted(at root: URL,
                              allowedHosts: [String] = [],
                              environment: (@Sendable () -> [String: String])? = nil,
                              arguments: (@Sendable () -> [String])? = nil) -> Sandbox

    public static func appContainer(id: String? = nil,
                                    allowedHosts: [String] = [],
                                    environment: (@Sendable () -> [String: String])? = nil,
                                    arguments: (@Sendable () -> [String])? = nil) -> Sandbox

    public struct Denial: Error, Sendable {
        public let url: URL
        public let reason: String
        public let suggestion: URL?
    }
}
```

`Sandbox.rooted(at:)` populates `environment` with `["PWD": root.path]` if the caller doesn't supply one, so `Sandbox.currentDirectory` lands at root by default for the simple case.

### 6.4 — Future `Shell` composition (informative, not v1)

If/when SwiftPorts (or an embedder like SwiftBash) introduces a `Shell` type for script execution, it composes with `Sandbox` rather than replacing it:

```swift
public final class Shell {
    @TaskLocal public static var current: Shell
    public var sandbox: Sandbox?
    public var environment: Environment

    public func withCurrent<T>(_ body: () async throws -> T) async rethrows -> T {
        try await Shell.$current.withValue(self) {
            try await Sandbox.$current.withValue(self.sandbox) {
                try await body()
            }
        }
    }
}
```

Shell binds itself task-locally and re-binds Sandbox in the same scope. SwiftPorts code keeps reading `Sandbox.current`; it neither knows nor cares that a Shell wrapped the bind. Apps without Shell still bind `Sandbox.$current.withValue(...)` directly — Sandbox stays usable without Shell.

### 6.5 — Ready to proceed

Step 2 (Phase 1 module + Phase 2 retrofit) proceeds based on this resolved direction. Any future deviation is recorded as a new issue.
