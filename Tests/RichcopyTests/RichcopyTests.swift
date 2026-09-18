import AppKit
import Testing
@testable import RichcopyCore

private let sample = """
# Navigation Review
This is **bold** and *italic* with a [link](https://example.com) and `code`.
- Item 1
- Item 2
"""

@MainActor
private func renderedHTML(_ markdown: String) throws -> String {
    let rendered = try render(markdown: markdown)
    return try #require(String(data: rendered.html, encoding: .utf8))
}

// MARK: - HTML flavor

@MainActor @Test func headingsGetRealTags() throws {
    let html = try renderedHTML("# Big\n\n## Small")
    #expect(html.contains("<h1>Big</h1>"))
    #expect(html.contains("<h2>Small</h2>"))
}

@MainActor @Test func inlineStylesGetRealTags() throws {
    let html = try renderedHTML("**bold** *italic* ~~struck~~ `code`")
    #expect(html.contains("<strong>bold</strong>"))
    #expect(html.contains("<em>italic</em>"))
    #expect(html.contains("<del>struck</del>"))
    #expect(html.contains("<code>code</code>"))
}

@MainActor @Test func singleNewlinesConvertToHardBreaksByDefault() throws {
    let html = try renderedHTML("Line 1\nLine 2")
    #expect(html.contains("Line 1<br>Line 2"))

    let rendered = try render(markdown: "Line 1\nLine 2")
    let rtfData = try #require(rendered.rtf)
    let attributed = try #require(NSAttributedString(rtf: rtfData, documentAttributes: nil))
    #expect(attributed.string.contains("Line 1\nLine 2"))
}

@MainActor @Test func noBreaksOptionPreservesCommonMarkSoftBreaks() throws {
    let rendered = try render(markdown: "Line 1\nLine 2", hardBreaks: false)
    let html = try #require(String(data: rendered.html, encoding: .utf8))
    #expect(html.contains("Line 1 Line 2"))
    #expect(!html.contains("<br>"))

    let rtfData = try #require(rendered.rtf)
    let attributed = try #require(NSAttributedString(rtf: rtfData, documentAttributes: nil))
    #expect(attributed.string.contains("Line 1 Line 2"))
}

@MainActor @Test func linksAndAutolinksWork() throws {
    let html = try renderedHTML("[named](https://example.com/a) and bare https://example.com/b")
    #expect(html.contains("<a href=\"https://example.com/a\">named</a>"))
    #expect(html.contains("<a href=\"https://example.com/b\">"))
}

@MainActor @Test func listsGetStructure() throws {
    let html = try renderedHTML("- one\n- two\n\n1. first\n2. second")
    #expect(html.contains("<ul>"))
    #expect(html.contains("<ol>"))
    #expect(html.contains("<li>one</li>"))
    #expect(!html.contains("<li><p>"))
}

@MainActor @Test func tablesRenderWithAlignment() throws {
    let html = try renderedHTML("""
    | Name | Count |
    | ---- | ----: |
    | API  | 42    |
    """)
    #expect(html.contains("<table>"))
    #expect(html.contains("<thead><tr><th>Name</th>"))
    #expect(html.contains("<td style=\"text-align:right\">42</td>"))
    #expect(html.contains("<td>API</td>"))
}

@MainActor @Test func taskListsGetCheckboxes() throws {
    let html = try renderedHTML("- [x] shipped\n- [ ] open")
    #expect(html.contains("☑ shipped"))
    #expect(html.contains("☐ open"))
}

@MainActor @Test func codeBlocksAndQuotesAndRules() throws {
    let html = try renderedHTML("```swift\nlet x = 1\n```\n\n> quoted\n\n---")
    #expect(html.contains("<pre><code class=\"language-swift\">"))
    #expect(html.contains("let x = 1"))
    #expect(html.contains("<blockquote>"))
    #expect(html.contains("<hr>"))
}

@MainActor @Test func htmlSpecialCharactersAreEscaped() throws {
    let html = try renderedHTML("a < b & c > d")
    #expect(html.contains("a &lt; b &amp; c &gt; d"))
}

// MARK: - RTF flavor

@MainActor @Test func rtfIsStyledRTFDocument() throws {
    let rendered = try render(markdown: sample)
    let rtfData = try #require(rendered.rtf)
    let rtf = try #require(String(data: rtfData, encoding: .utf8))
    #expect(rtf.hasPrefix("{\\rtf1"))
    #expect(rtf.contains("\\b"))
    #expect(rtf.contains("HYPERLINK"))
}

@MainActor @Test func noRTFOptionSkipsRTFFlavor() throws {
    let rendered = try render(markdown: sample, includeRTF: false)
    #expect(rendered.rtf == nil)
    #expect(!rendered.html.isEmpty)
    #expect(rendered.plainText == sample)

    let pasteboard = NSPasteboard(name: NSPasteboard.Name("richcopy.tests.nortf"))
    defer { pasteboard.releaseGlobally() }

    #expect(copy(rendered, to: pasteboard))
    let types = pasteboard.types ?? []
    #expect(!types.contains(.rtf))
    #expect(types.contains(.html))
    #expect(types.contains(.string))
}

// MARK: - Plain-text flavor

@MainActor @Test func plainTextIsOriginalMarkdown() throws {
    let rendered = try render(markdown: sample + "\n")
    #expect(rendered.plainText == sample)
}

// MARK: - Errors

@MainActor @Test func emptyInputThrows() {
    #expect(throws: RichcopyError.self) {
        try render(markdown: "   \n  ")
    }
}

// MARK: - Pasteboard

@MainActor @Test func registersAllThreeFlavorsOnPasteboard() throws {
    let rendered = try render(markdown: sample)

    // Private pasteboard so tests never clobber the user's clipboard.
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("richcopy.tests"))
    defer { pasteboard.releaseGlobally() }

    #expect(copy(rendered, to: pasteboard))

    let types = pasteboard.types ?? []
    #expect(types.contains(.rtf))
    #expect(types.contains(.html))
    #expect(types.contains(.string))

    let readBack = try #require(pasteboard.string(forType: .string))
    #expect(readBack.contains("Navigation Review"))
}

// MARK: - Agent Skill Definition

@Test func skillDefinitionIsValid() {
    #expect(!richcopySkillDefinition.isEmpty)
    #expect(richcopySkillDefinition.hasPrefix("---\nname: richcopy\n"))
    #expect(richcopySkillDefinition.contains("description:"))
    #expect(richcopySkillDefinition.contains("cat <<'EOF' | richcopy --no-rtf"))
    #expect(richcopySkillDefinition.contains("pbcopy"))
    #expect(richcopySkillDefinition.contains("--no-breaks"))
    #expect(richcopySkillDefinition.contains("Slack Layout & Styling Preferences:"))
}
