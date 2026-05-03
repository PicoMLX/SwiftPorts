import Foundation

/// `fnmatch(3)`-style glob matcher: `*` matches any run of characters,
/// `?` matches any single character. No bracket expressions.
///
/// Used by zip / unzip include / exclude lists.
public enum GlobMatcher {
    public static func matches(
        pattern: String,
        name: String,
        caseInsensitive: Bool = false
    ) -> Bool {
        let p = Array(caseInsensitive ? pattern.lowercased() : pattern)
        let n = Array(caseInsensitive ? name.lowercased() : name)
        var memo: [[Bool?]] = Array(
            repeating: Array(repeating: nil, count: n.count + 1),
            count: p.count + 1)
        func match(_ i: Int, _ j: Int) -> Bool {
            if let cached = memo[i][j] { return cached }
            let result: Bool
            if i == p.count {
                result = j == n.count
            } else if p[i] == "*" {
                result = match(i + 1, j) || (j < n.count && match(i, j + 1))
            } else if j < n.count && (p[i] == "?" || p[i] == n[j]) {
                result = match(i + 1, j + 1)
            } else {
                result = false
            }
            memo[i][j] = result
            return result
        }
        return match(0, 0)
    }

    /// True if any pattern matches `name`. Empty list → matches nothing.
    public static func matchesAny(
        patterns: [String],
        name: String,
        caseInsensitive: Bool = false
    ) -> Bool {
        for p in patterns where matches(
            pattern: p, name: name, caseInsensitive: caseInsensitive)
        {
            return true
        }
        return false
    }
}
