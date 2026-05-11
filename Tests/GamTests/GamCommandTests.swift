import Testing
import Foundation
@testable import GamCommand
import GamKit

@Suite struct GamCommandTests {
    @Test func parseStyleHandlesBundled() {
        if case .bundled(.dark) = Gam.parseStyle("dark") {} else { Issue.record("expected .bundled(.dark)") }
        if case .bundled(.light) = Gam.parseStyle("LIGHT") {} else { Issue.record("expected .bundled(.light)") }
        if case .bundled(.notty) = Gam.parseStyle("none") {} else { Issue.record("expected .bundled(.notty)") }
        if case .auto = Gam.parseStyle("auto") {} else { Issue.record("expected .auto") }
    }

    @Test func parseStyleUnknownFallsBackToAuto() {
        if case .auto = Gam.parseStyle("definitely-not-a-style") {} else {
            Issue.record("expected .auto fallback")
        }
    }
}
