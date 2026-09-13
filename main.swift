import Foundation
import AppKit

func printUsage() {
    let usage = """
    Usage:
      echo "**bold** [link](https://example.com)" | richcopy
      richcopy < file.md
      richcopy "Direct **markdown** string"
      richcopy --test

    Description:
      Parses Markdown using Apple's native CommonMark parser and copies
      it to the macOS clipboard simultaneously as HTML, RTF, and Plain Text.
      When pasting into Slack, Notion, Google Docs, Apple Mail, etc.,
      the receiving app automatically picks up the styled rich text.
    """
    print(usage)
}

func runTests() -> Int32 {
    print("Running richcopy unit tests...")
    let sample = """
    # Navigation Review
    This is **bold** and *italic* with a [link](https://greenline.ai) and `code`.
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
        assert(htmlString.contains("https://greenline.ai"), "HTML must contain the hyperlink")
        assert(htmlString.contains("bold"), "HTML must contain bold text")

        // Test pasteboard write & read
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
        return 0
    } catch {
        fputs("Test failed with error: \(error.localizedDescription)\n", stderr)
        return 1
    }
}

func copyMarkdownToPasteboard(_ markdown: String) -> Int32 {
    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        fputs("richcopy: error: empty markdown input\n", stderr)
        return 1
    }

    do {
        let attr = try NSAttributedString(markdown: markdown)
        let range = NSRange(location: 0, length: attr.length)
        let rtfData = try attr.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let htmlData = try attr.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(rtfData, forType: .rtf)
        pb.setData(htmlData, forType: .html)
        pb.setString(attr.string, forType: .string)
        return 0
    } catch {
        fputs("richcopy: error parsing markdown: \(error.localizedDescription)\n", stderr)
        return 1
    }
}

let args = CommandLine.arguments

if args.count > 1 {
    let first = args[1]
    if first == "--help" || first == "-h" {
        printUsage()
        exit(0)
    } else if first == "--test" {
        exit(runTests())
    } else if !first.hasPrefix("-") {
        exit(copyMarkdownToPasteboard(first))
    }
}

if let data = try? FileHandle.standardInput.readToEnd(),
   let input = String(data: data, encoding: .utf8) {
    exit(copyMarkdownToPasteboard(input))
} else {
    fputs("richcopy: error reading from stdin\n", stderr)
    exit(1)
}
