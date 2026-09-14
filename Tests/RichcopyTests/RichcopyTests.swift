import AppKit
import Testing
@testable import RichcopyCore

private let sample = """
# Navigation Review
This is **bold** and *italic* with a [link](https://example.com) and `code`.
- Item 1
- Item 2
"""

@Test func parsesCommonMarkIntoAllFlavors() throws {
    let rendered = try render(markdown: sample)
    #expect(!rendered.rtf.isEmpty)
    #expect(!rendered.html.isEmpty)
    #expect(!rendered.plainText.isEmpty)
}

@Test func htmlPreservesLinksAndText() throws {
    let rendered = try render(markdown: sample)
    let html = try #require(String(data: rendered.html, encoding: .utf8))
    #expect(html.contains("https://example.com"))
    #expect(html.contains("bold"))
}

@Test func rtfIsValidRTFDocument() throws {
    let rendered = try render(markdown: sample)
    let rtf = try #require(String(data: rendered.rtf, encoding: .utf8))
    #expect(rtf.hasPrefix("{\\rtf1"))
}

@Test func plainTextStripsMarkdownSyntax() throws {
    let rendered = try render(markdown: "This is **bold** text")
    #expect(rendered.plainText == "This is bold text")
}

@Test func emptyInputThrows() {
    #expect(throws: RichcopyError.self) {
        try render(markdown: "   \n  ")
    }
}

@Test func registersAllThreeFlavorsOnPasteboard() throws {
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
