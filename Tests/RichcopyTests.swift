import Foundation
import AppKit

print("Running richcopy unit tests...")

let sample = """
# Navigation Review
This is **bold** and *italic* with a [link](https://example.com) and `code`.
- Item 1
- Item 2
"""

do {
    let attr = try NSAttributedString(markdown: sample)
    assert(attr.length > 0, "Parsed attributed string must not be empty")

    let range = NSRange(location: 0, length: attr.length)
    let rtfData = try attr.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    let htmlData = try attr.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])

    assert(!rtfData.isEmpty, "RTF data must not be empty")
    assert(!htmlData.isEmpty, "HTML data must not be empty")

    let htmlString = String(data: htmlData, encoding: .utf8) ?? ""
    assert(htmlString.contains("https://example.com"), "HTML must contain the hyperlink")
    assert(htmlString.contains("bold"), "HTML must contain bold text")

    let pb = NSPasteboard.general
    pb.clearContents()
    let rtfOk = pb.setData(rtfData, forType: .rtf)
    let htmlOk = pb.setData(htmlData, forType: .html)
    let strOk = pb.setString(attr.string, forType: .string)

    assert(rtfOk && htmlOk && strOk, "Must successfully write all 3 types to pasteboard")

    let types = pb.types ?? []
    assert(types.contains(.rtf), "Pasteboard must contain .rtf")
    assert(types.contains(.html), "Pasteboard must contain .html")
    assert(types.contains(.string), "Pasteboard must contain .string")

    let readPlain = pb.string(forType: .string) ?? ""
    assert(readPlain.contains("Navigation Review"), "Pasteboard plain text must be accurate")

    print("  ✓ CommonMark parsing verified")
    print("  ✓ RTF data generation verified")
    print("  ✓ HTML data generation verified")
    print("  ✓ NSPasteboard multi-flavor registration verified")
    print("All tests passed successfully!")
    exit(0)
} catch {
    fputs("Test failed with error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
