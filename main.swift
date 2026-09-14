import Foundation
import AppKit

func printUsage() {
    let usage = """
    Usage:
      echo "**bold** [link](https://example.com)" | richcopy
      richcopy < file.md
      richcopy "Direct **markdown** string"

    Description:
      Copies Markdown from your terminal to the macOS clipboard as rich text.
      Pastes with full formatting (bold, italics, links, lists) into Slack,
      Notion, Google Docs, Apple Mail, and other macOS apps.
    """
    print(usage)
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
        fputs("richcopy: error: \(error.localizedDescription)\n", stderr)
        return 1
    }
}

let args = CommandLine.arguments

if args.count > 1 {
    let first = args[1]
    if first == "--help" || first == "-h" {
        printUsage()
        exit(0)
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
