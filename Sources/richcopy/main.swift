import ArgumentParser
import Foundation
import RichcopyCore

struct Richcopy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "richcopy",
        abstract: "Copies Markdown from your terminal to the macOS clipboard as rich text.",
        discussion: """
        Pastes with full formatting (bold, italics, links, lists) into Slack,
        Notion, Google Docs, Apple Mail, and other macOS apps.

        Examples:
          echo "**bold** [link](https://example.com)" | richcopy
          richcopy < file.md
          richcopy "Direct **markdown** string"
        """
    )

    @Flag(name: [.customShort("V"), .long], help: "Show the version.")
    var version = false

    @Argument(help: "Markdown text to copy. If omitted, reads from standard input.")
    var text: [String] = []

    func run() throws {
        if version {
            print("0.1.0")
            return
        }
        let input: String
        if !text.isEmpty {
            input = text.joined(separator: " ")
        } else {
            guard let data = try? FileHandle.standardInput.readToEnd(),
                  let stdinText = String(data: data, encoding: .utf8) else {
                fputs("richcopy: error reading from stdin\n", stderr)
                throw ExitCode.failure
            }
            input = stdinText
        }

        let success = MainActor.assumeIsolated {
            do {
                let rendered = try render(markdown: input)
                guard copy(rendered) else {
                    fputs("richcopy: error: failed to write to pasteboard\n", stderr)
                    return false
                }
                return true
            } catch {
                fputs("richcopy: error: \(error.localizedDescription)\n", stderr)
                return false
            }
        }

        if !success {
            throw ExitCode.failure
        }
    }
}

Richcopy.main()
