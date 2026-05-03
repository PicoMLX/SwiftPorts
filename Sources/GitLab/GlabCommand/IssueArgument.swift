import Foundation
import GitLab

/// Resolves an issue argument that may be a number, `#123`, or a full
/// GitLab issue URL. Returns the IID plus an optional repository
/// reference parsed from the URL (if URL form was used).
enum IssueArgument {
    struct Parsed {
        let iid: Int
        let repoFromURL: RepositoryReference?
    }

    static func parse(_ raw: String) throws -> Parsed {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // URL form: https://gitlab.com/group/sub/repo/-/issues/123
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return try parseURL(url)
        }

        // Numeric form (with or without leading `#`).
        let stripped = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard let iid = Int(stripped), iid > 0 else {
            throw IssueArgumentError.malformed(raw)
        }
        return Parsed(iid: iid, repoFromURL: nil)
    }

    private static func parseURL(_ url: URL) throws -> Parsed {
        guard let host = url.host, !host.isEmpty else {
            throw IssueArgumentError.malformed(url.absoluteString)
        }
        // Path shape (after leading slash): group(/sub)*/repo[/-]/issues[/incident]/<id>
        let raw = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = raw.split(separator: "/").map(String.init)
        guard let issuesIdx = segments.lastIndex(of: "issues") else {
            throw IssueArgumentError.malformed(url.absoluteString)
        }
        // The issue IID comes after "issues" (or after "issues/incident").
        var idIdx = issuesIdx + 1
        if idIdx < segments.count, segments[idIdx] == "incident" { idIdx += 1 }
        guard idIdx < segments.count, let iid = Int(segments[idIdx]), iid > 0 else {
            throw IssueArgumentError.malformed(url.absoluteString)
        }
        // Repo path = segments before the optional `-` separator
        // (which sits right before `issues`), so trim those.
        var repoEnd = issuesIdx
        if repoEnd > 0, segments[repoEnd - 1] == "-" { repoEnd -= 1 }
        let repoSegments = Array(segments[..<repoEnd])
        guard repoSegments.count >= 2 else {
            throw IssueArgumentError.malformed(url.absoluteString)
        }
        let ref = RepositoryReference(host: host, pathSegments: repoSegments)
        return Parsed(iid: iid, repoFromURL: ref)
    }
}

enum IssueArgumentError: Error, LocalizedError {
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .malformed(let s):
            return "Invalid issue argument: \"\(s)\". Expected a number, `#123`, or a full URL."
        }
    }
}
