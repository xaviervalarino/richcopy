import ArgumentParser
import Foundation
import RichcopyCore

// MARK: - Agent Skill Helpers

private func agentSkillPaths() -> [URL] {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    var paths: [URL] = []

    let claudeDir = home.appendingPathComponent(".claude/skills")
    let geminiDir = home.appendingPathComponent(".gemini/config/skills")

    if fm.fileExists(atPath: claudeDir.path) {
        paths.append(claudeDir.appendingPathComponent("richcopy"))
    }
    if fm.fileExists(atPath: geminiDir.path) {
        paths.append(geminiDir.appendingPathComponent("richcopy"))
    }
    if paths.isEmpty {
        paths.append(claudeDir.appendingPathComponent("richcopy"))
    }
    return paths
}

private func installAgentSkill() {
    let fm = FileManager.default
    let targets = agentSkillPaths()
    var installed: [String] = []

    for dir in targets {
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent("SKILL.md")
            try richcopySkillDefinition.write(to: fileURL, atomically: true, encoding: .utf8)
            installed.append(fileURL.path)
        } catch {
            fputs("richcopy: warning: failed to install skill to \(dir.path): \(error.localizedDescription)\n", stderr)
        }
    }

    if !installed.isEmpty {
        print("Installed richcopy skill:")
        for path in installed {
            print("  ✓ \(path)")
        }
        print("\nFor other agents (ChatGPT, Cursor, OpenCode):")
        print("  richcopy --print-skill > <your-agent-rules-file>")
    } else {
        fputs("richcopy: error: could not install skill to any location\n", stderr)
        exit(1)
    }
}

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
        """
    )

    @Flag(name: .customLong("no-rtf"), help: "Skip RTF generation for ultra-fast copying (HTML + plain text). Most macOS apps (Slack, Notion, Google Docs, Apple Mail, Apple Notes) paste rich text directly from HTML.")
    var noRTF = false

    @Flag(name: .customLong("install-skill"), help: "Install the agent skill into detected directories (supported: Claude Code, Antigravity).")
    var installSkill = false

    @Flag(name: .customLong("print-skill"), help: "Print the SKILL.md definition to standard output (for ChatGPT, Cursor, OpenCode, or custom prompts).")
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
        if installSkill {
            installAgentSkill()
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
        let success = MainActor.assumeIsolated {
            do {
                let rendered = try render(markdown: input, includeRTF: !skipRTF)
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
