import ArgumentParser
import Foundation
import RichcopyCore

// MARK: - CLI Command

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
          richcopy --print-skill > ~/.claude/skills/richcopy/SKILL.md
        """
    )

    @Flag(name: .customLong("no-rtf"), help: "Skip RTF generation for ultra-fast copying (HTML + plain text). Most macOS apps (Slack, Notion, Google Docs, Apple Mail, Apple Notes) paste rich text directly from HTML.")
    var noRTF = false

    @Flag(name: .customLong("no-breaks"), help: "Do not convert single newlines to hard line breaks. By default, richcopy converts single newlines to hard breaks so text pastes cleanly into chat apps.")
    var noBreaks = false

    @Flag(name: .customLong("print-skill"), help: "Print the agent skill definition to standard output.")
    var printSkill = false

    @Flag(name: [.customShort("V"), .long], help: "Show the version.")
    var version = false

    @Argument(help: "Markdown text to copy. If omitted, reads from standard input.")
    var text: [String] = []

    func run() throws {
        if version {
            print("0.1.0")
            return
        }
        if printSkill {
            print(richcopySkillDefinition)
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

        let skipRTF = noRTF
        let hardBreaks = !noBreaks
        let success = MainActor.assumeIsolated {
            do {
                let rendered = try render(markdown: input, includeRTF: !skipRTF, hardBreaks: hardBreaks)
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
