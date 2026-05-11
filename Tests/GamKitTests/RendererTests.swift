import Foundation
import Testing
@testable import GamKit

@Suite struct RendererTests {

    /// Forces the `notty` (no-color) style so we can do exact string
    /// assertions without ANSI noise.
    private func render(_ input: String, wordWrap: Int = 80) throws -> String {
        let renderer = try Renderer(
            style: .bundled(.notty),
            wordWrap: wordWrap,
            terminal: Terminal(
                colorEnabled: false,
                trueColor: false,
                eightBitColor: false,
                hyperlinks: false,
                background: .none
            )
        )
        return try renderer.render(input)
    }

    @Test func headingsKeepHashPrefix() throws {
        let out = try render("# Hello\n\n## World\n")
        #expect(out.contains("# Hello"))
        #expect(out.contains("## World"))
    }

    @Test func paragraphsWrap() throws {
        let lorem = String(repeating: "word ", count: 30)
        let out = try render(lorem, wordWrap: 40)
        let lines = out.split(separator: "\n")
        // Notty has a document margin of 2, so allow margin chars
        // when checking width.
        for line in lines where !line.isEmpty {
            #expect(line.count <= 60, "line too long: \(line)")
        }
    }

    @Test func inlineCodeUsesPrefixSuffix() throws {
        let out = try render("Run `swift build` now.")
        #expect(out.contains("`swift build`"))
    }

    @Test func bundledStylesDecode() throws {
        for style in BundledStyle.allCases {
            _ = try StyleConfig.bundled(style)
        }
    }

    @Test func linksRenderURLWhenHyperlinksOff() throws {
        let out = try render("Read [the docs](https://example.com).")
        #expect(out.contains("https://example.com"))
        #expect(out.contains("the docs"))
    }

    @Test func unorderedListBullets() throws {
        let out = try render("- one\n- two\n- three")
        #expect(out.contains("• one"))
        #expect(out.contains("• two"))
        #expect(out.contains("• three"))
    }

    @Test func taskListCheckboxes() throws {
        let out = try render("- [x] done\n- [ ] open")
        #expect(out.contains("[x] done"))
        #expect(out.contains("[ ] open"))
    }
}
