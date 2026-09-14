import Foundation
import RichcopyCore

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

@MainActor
func run(markdown: String) -> Int32 {
    do {
        let rendered = try render(markdown: markdown)
        guard copy(rendered) else {
            fputs("richcopy: error: failed to write to pasteboard\n", stderr)
            return 1
        }
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
        exit(run(markdown: first))
    }
}

if let data = try? FileHandle.standardInput.readToEnd(),
   let input = String(data: data, encoding: .utf8) {
    exit(run(markdown: input))
} else {
    fputs("richcopy: error reading from stdin\n", stderr)
    exit(1)
}
