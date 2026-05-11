import Foundation
import GamKit

/// Render `glab` body text (MR / issue / release description) through
/// GamKit. Mirrors the GhCommand-side helper of the same name — kept
/// duplicated rather than hoisted into ForgeKit so neither umbrella
/// gains an extra cross-tree dependency for a five-line shim.
enum MarkdownBody {
    static func render(_ body: String) -> String {
        do {
            return try Gam.render(body)
        } catch {
            return body
        }
    }
}
