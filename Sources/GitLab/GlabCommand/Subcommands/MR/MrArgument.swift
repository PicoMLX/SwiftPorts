import Foundation
import GitLab

/// Resolves an MR argument that may be a number, `!123`, `#123`,
/// or a full GitLab merge-request URL. Returns the IID plus an
/// optional repository reference parsed from the URL.
enum MrArgument {
    struct Parsed {
        let iid: Int
        let repoFromURL: RepositoryReference?
    }

    static func parse(_ raw: String) throws -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return try parseURL(url)
        }

        var stripped = trimmed
        if stripped.hasPrefix("!") || stripped.hasPrefix("#") {
            stripped = String(stripped.dropFirst())
        }
        guard let iid = Int(stripped), iid > 0 else {
            throw MrArgumentError.malformed(raw)
        }
        return Parsed(iid: iid, repoFromURL: nil)
    }

    private static func parseURL(_ url: URL) throws -> Parsed {
        guard let host = url.host, !host.isEmpty else {
            throw MrArgumentError.malformed(url.absoluteString)
        }
        let raw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = raw.split(separator: "/").map(String.init)
        guard let mrIdx = segments.lastIndex(of: "merge_requests") else {
            throw MrArgumentError.malformed(url.absoluteString)
        }
        let idIdx = mrIdx + 1
        guard idIdx < segments.count, let iid = Int(segments[idIdx]), iid > 0 else {
            throw MrArgumentError.malformed(url.absoluteString)
        }
        var repoEnd = mrIdx
        if repoEnd > 0, segments[repoEnd - 1] == "-" { repoEnd -= 1 }
        let repoSegments = Array(segments[..<repoEnd])
        guard repoSegments.count >= 2 else {
            throw MrArgumentError.malformed(url.absoluteString)
        }
        let ref = RepositoryReference(host: host, pathSegments: repoSegments)
        return Parsed(iid: iid, repoFromURL: ref)
    }
}

enum MrArgumentError: Error, LocalizedError {
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .malformed(let s):
            return "Invalid MR argument: \"\(s)\". Expected a number, `!123`, `#123`, or a full URL."
        }
    }
}
