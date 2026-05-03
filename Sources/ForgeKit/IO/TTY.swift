import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Lightweight TTY + colour-capability detection. Mirrors what gh does
/// in `pkg/iostreams/iostreams.go` — without the colour scheme zoo.
public enum TTY {
    /// True when stdout is attached to a terminal.
    public static var isStdoutTTY: Bool {
        isatty(fileno(stdout)) != 0
    }

    /// True when stderr is attached to a terminal.
    public static var isStderrTTY: Bool {
        isatty(fileno(stderr)) != 0
    }

    /// True when colour escape codes should be emitted on stdout.
    /// Honors `NO_COLOR` (kill switch), `CLICOLOR_FORCE` (force-on),
    /// and otherwise gates on stdout-is-a-TTY.
    public static var isStdoutColorEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        if let v = env["NO_COLOR"], !v.isEmpty { return false }
        if let v = env["CLICOLOR_FORCE"], !v.isEmpty, v != "0" { return true }
        return isStdoutTTY
    }
}
