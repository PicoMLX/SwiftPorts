import Foundation

/// Output modes mirroring the `sqlite3` shell's `.mode` settings.
public enum OutputMode: String, Sendable, CaseIterable {
    case list, csv, line, column, json
}

/// Renders result sets the way the `sqlite3` shell does for each output
/// mode. Shared by the CLI and any embedder that wants matching output.
public struct ResultFormatter: Sendable {
    public var mode: OutputMode
    public var showHeader: Bool
    public var separator: String
    public var nullValue: String

    public init(mode: OutputMode = .list,
                showHeader: Bool = false,
                separator: String = "|",
                nullValue: String = "") {
        self.mode = mode
        self.showHeader = showHeader
        self.separator = separator
        self.nullValue = nullValue
    }

    public func render(_ set: ResultSet) -> String {
        switch mode {
        case .list: return renderList(set)
        case .csv: return renderCSV(set)
        case .line: return renderLine(set)
        case .column: return renderColumn(set)
        case .json: return renderJSON(set)
        }
    }

    private func text(_ value: SQLiteValue) -> String { value.cliText ?? nullValue }

    private func joinLines(_ lines: [String]) -> String {
        lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    private func renderList(_ set: ResultSet) -> String {
        var lines: [String] = []
        if showHeader { lines.append(set.columns.joined(separator: separator)) }
        for row in set.rows {
            lines.append(row.map(text).joined(separator: separator))
        }
        return joinLines(lines)
    }

    private func renderCSV(_ set: ResultSet) -> String {
        // SQLite's CSV mode terminates every row with CRLF, including the
        // last one.
        var rows: [String] = []
        if showHeader { rows.append(set.columns.map(csvField).joined(separator: ",")) }
        for row in set.rows {
            rows.append(row.map { csvField(text($0)) }.joined(separator: ","))
        }
        return rows.map { $0 + "\r\n" }.joined()
    }

    private func csvField(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private func renderLine(_ set: ResultSet) -> String {
        guard !set.columns.isEmpty else { return "" }
        let width = set.columns.map(\.count).max() ?? 0
        var blocks: [String] = []
        for row in set.rows {
            let lines = set.columns.enumerated().map { (i, col) -> String in
                let pad = String(repeating: " ", count: max(0, width - col.count))
                return "\(pad)\(col) = \(text(row[i]))"
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        return blocks.isEmpty ? "" : blocks.joined(separator: "\n\n") + "\n"
    }

    private func renderColumn(_ set: ResultSet) -> String {
        let cells = set.rows.map { $0.map(text) }
        var widths = set.columns.map(\.count)
        for row in cells {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], cell.count)
            }
        }
        func pad(_ s: String, _ w: Int) -> String {
            s + String(repeating: " ", count: max(0, w - s.count))
        }
        var lines: [String] = []
        if showHeader {
            lines.append(zip(set.columns, widths).map { pad($0, $1) }.joined(separator: "  "))
            lines.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
        }
        for row in cells {
            lines.append(zip(row, widths).map { pad($0, $1) }.joined(separator: "  "))
        }
        // SQLite pads every cell (including the last column) to its width,
        // so trailing spaces are preserved.
        return joinLines(lines)
    }

    private func renderJSON(_ set: ResultSet) -> String {
        let objects = set.rows.map { row -> String in
            let pairs = set.columns.enumerated().map { (i, col) in
                "\(jsonString(col)):\(jsonValue(row[i]))"
            }
            return "{" + pairs.joined(separator: ",") + "}"
        }
        return "[" + objects.joined(separator: ",\n") + "]\n"
    }

    private func jsonValue(_ value: SQLiteValue) -> String {
        switch value {
        case .null: return "null"
        case .integer(let i): return String(i)
        // sqlite3's JSON mode prints reals with its own full-precision dtoa
        // (e.g. 3.14 → 3.140000000000000124). We emit the shortest
        // round-tripping form instead — equivalent value, cleaner text,
        // since reproducing sqlite's dtoa byte-for-byte isn't possible via
        // the platform formatter.
        case .real(let d): return String(d)
        case .text(let s): return jsonString(s)
        case .blob(let b): return jsonBlob(b)
        }
    }

    /// SQLite renders BLOBs in JSON as a string of `\u00XX` escapes, one
    /// per byte.
    private func jsonBlob(_ bytes: Data) -> String {
        "\"" + bytes.map { String(format: "\\u%04x", $0) }.joined() + "\""
    }

    private func jsonString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}
