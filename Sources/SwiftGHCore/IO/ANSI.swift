import Foundation

/// Minimal ANSI colour helpers. Inert when ``TTY/isStdoutColorEnabled``
/// is false — caller can wrap unconditionally without checking.
public enum ANSI {
    public static var enabled: Bool { TTY.isStdoutColorEnabled }

    public static func wrap(_ string: String, _ codes: Code...) -> String {
        guard enabled, !codes.isEmpty else { return string }
        let prefix = codes.map { "\u{1B}[\($0.rawValue)m" }.joined()
        return prefix + string + "\u{1B}[0m"
    }

    public static func bold(_ s: String) -> String { wrap(s, .bold) }
    public static func dim(_ s: String) -> String { wrap(s, .dim) }
    public static func red(_ s: String) -> String { wrap(s, .red) }
    public static func green(_ s: String) -> String { wrap(s, .green) }
    public static func yellow(_ s: String) -> String { wrap(s, .yellow) }
    public static func blue(_ s: String) -> String { wrap(s, .blue) }
    public static func magenta(_ s: String) -> String { wrap(s, .magenta) }
    public static func cyan(_ s: String) -> String { wrap(s, .cyan) }
    public static func gray(_ s: String) -> String { wrap(s, .brightBlack) }

    public enum Code: Int, Sendable {
        case bold = 1
        case dim = 2
        case italic = 3
        case underline = 4

        case black = 30
        case red = 31
        case green = 32
        case yellow = 33
        case blue = 34
        case magenta = 35
        case cyan = 36
        case white = 37
        case brightBlack = 90
    }
}
