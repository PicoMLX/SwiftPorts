import ArgumentParser
import Foundation
import GitLab

/// Allows `--repo` and bare positional arguments to take any of:
///   - `OWNER/REPO`
///   - `GROUP/NAMESPACE/REPO` (or deeper subgroup chains)
///   - `HOST/OWNER/REPO`
///   - a full HTTPS or SSH URL
extension RepositoryReference: ExpressibleByArgument {
    public init?(argument: String) {
        if let url = URL(string: argument), url.scheme != nil,
           let parsed = RepositoryReference(parsingRemoteURL: url) {
            self = parsed
            return
        }
        do {
            self = try RepositoryReference(parsing: argument)
        } catch {
            return nil
        }
    }
}
